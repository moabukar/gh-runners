"""Scale-Up Lambda - Launches EC2 runners."""
import base64
import json
import logging
import os
import time
import random
from datetime import datetime, timezone
from functools import wraps
from typing import Callable, Any
import boto3
import urllib.request
import http.client

try:
    import jwt
except ImportError:
    # Fallback if PyJWT not available (should use Lambda layer)
    jwt = None
    logging.warning("PyJWT not available - Lambda layer may be missing")

SECRET_ARN = os.environ["SECRET_ARN"]
GITHUB_ORG = os.environ["GITHUB_ORG"]
RUNNER_GROUP = os.environ.get("RUNNER_GROUP", "default")
RUNNER_LABELS = os.environ.get("RUNNER_LABELS", "self-hosted,linux,x64").split(",")
SUBNET_IDS = os.environ["SUBNET_IDS"].split(",")
SECURITY_GROUP_IDS = os.environ["SECURITY_GROUP_IDS"].split(",")
INSTANCE_PROFILE_ARN = os.environ["INSTANCE_PROFILE_ARN"]
AMI_ID = os.environ["AMI_ID"]
INSTANCE_TYPES = os.environ.get("INSTANCE_TYPES", "m5.large").split(",")
SPOT_ENABLED = os.environ.get("SPOT_ENABLED", "true").lower() == "true"
RUNNERS_MAX = int(os.environ.get("RUNNERS_MAX", "10"))
KEY_NAME = os.environ.get("KEY_NAME", "")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

ec2 = boto3.client("ec2")
secrets = boto3.client("secretsmanager")
cloudwatch = boto3.client("cloudwatch")
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

def put_metric(namespace: str, metric_name: str, value: float, unit: str = "Count", dimensions: dict = None):
    """Put custom CloudWatch metric."""
    try:
        cloudwatch.put_metric_data(
            Namespace=namespace,
            MetricData=[{
                "MetricName": metric_name,
                "Value": value,
                "Unit": unit,
                "Dimensions": [{"Name": k, "Value": v} for k, v in (dimensions or {}).items()]
            }]
        )
    except Exception as e:
        logger.warning(f"Failed to put metric {metric_name}: {e}")

def retry_github_api(max_retries: int = 3, backoff_factor: float = 2.0):
    """Decorator for GitHub API calls with exponential backoff and rate limit handling."""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except urllib.error.HTTPError as e:
                    last_exception = e
                    if e.code == 403:
                        # Rate limit hit
                        retry_after = int(e.headers.get("Retry-After", backoff_factor ** attempt))
                        logger.warning(f"Rate limited (attempt {attempt + 1}/{max_retries}), waiting {retry_after}s")
                        time.sleep(retry_after)
                    elif e.code in [500, 502, 503, 504]:
                        # Server errors - retry with backoff
                        wait_time = backoff_factor ** attempt
                        logger.warning(f"Server error {e.code} (attempt {attempt + 1}/{max_retries}), waiting {wait_time}s")
                        time.sleep(wait_time)
                    else:
                        # Don't retry on client errors (4xx except 403)
                        raise
                except Exception as e:
                    last_exception = e
                    if attempt < max_retries - 1:
                        wait_time = backoff_factor ** attempt
                        logger.warning(f"Error (attempt {attempt + 1}/{max_retries}): {e}, waiting {wait_time}s")
                        time.sleep(wait_time)
                    else:
                        raise
            
            if last_exception:
                raise last_exception
            return None
        return wrapper
    return decorator

_github_app_config = None

def get_github_app_config():
    global _github_app_config
    if _github_app_config is None:
        response = secrets.get_secret_value(SecretId=SECRET_ARN)
        _github_app_config = json.loads(response["SecretString"])
    return _github_app_config

def generate_jwt():
    if jwt is None:
        raise ImportError("PyJWT not available - Lambda layer missing")
    config = get_github_app_config()
    private_key = base64.b64decode(config["private_key"]).decode()
    now = int(time.time())
    payload = {"iat": now - 60, "exp": now + 600, "iss": config["app_id"]}
    return jwt.encode(payload, private_key, algorithm="RS256")

@retry_github_api(max_retries=3)
def get_installation_token():
    config = get_github_app_config()
    jwt_token = generate_jwt()
    url = f"https://api.github.com/app/installations/{config['installation_id']}/access_tokens"
    req = urllib.request.Request(url, method="POST", headers={
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())["token"]

@retry_github_api(max_retries=3)
def get_runner_registration_token():
    token = get_installation_token()
    url = f"https://api.github.com/orgs/{GITHUB_ORG}/actions/runners/registration-token"
    req = urllib.request.Request(url, method="POST", headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())["token"]

def count_running_runners():
    """Count currently running or pending runner instances."""
    paginator = ec2.get_paginator("describe_instances")
    count = 0
    
    for page in paginator.paginate(Filters=[
        {"Name": "tag:Purpose", "Values": ["github-runner"]},
        {"Name": "instance-state-name", "Values": ["pending", "running"]},
    ]):
        for reservation in page.get("Reservations", []):
            count += len(reservation.get("Instances", []))
    
    return count

def generate_user_data(registration_token, labels, runner_name):
    labels_str = ",".join(labels)
    script = f"""#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/runner-setup.log) 2>&1
cd /home/runner/actions-runner
sudo -u runner ./config.sh --url "https://github.com/{GITHUB_ORG}" --token "{registration_token}" --name "{runner_name}" --labels "{labels_str}" --runnergroup "{RUNNER_GROUP}" --ephemeral --unattended --disableupdate
sudo -u runner ./run.sh &
RUNNER_PID=$!
TIMEOUT=14400
ELAPSED=0
while kill -0 $RUNNER_PID 2>/dev/null; do
    sleep 30
    ELAPSED=$((ELAPSED + 30))
    [ $ELAPSED -ge $TIMEOUT ] && break
done
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
"""
    return base64.b64encode(script.encode()).decode()

def launch_runner(job):
    """Launch EC2 runner with fallback to multiple instance types."""
    registration_token = get_runner_registration_token()
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    runner_name = f"runner-{timestamp}-{job.get('id', 'unknown')}"
    labels = list(set(RUNNER_LABELS + job.get("labels", [])))
    user_data = generate_user_data(registration_token, labels, runner_name)
    
    # Try each instance type until one succeeds
    last_error = None
    for instance_type in INSTANCE_TYPES:
        try:
            params = {
                "ImageId": AMI_ID,
                "MinCount": 1,
                "MaxCount": 1,
                "SubnetId": random.choice(SUBNET_IDS),
                "SecurityGroupIds": SECURITY_GROUP_IDS,
                "UserData": user_data,
                "IamInstanceProfile": {"Arn": INSTANCE_PROFILE_ARN},
                "InstanceType": instance_type,
                "TagSpecifications": [{
                    "ResourceType": "instance",
                    "Tags": [
                        {"Key": "Name", "Value": runner_name},
                        {"Key": "Purpose", "Value": "github-runner"},
                        {"Key": "JobId", "Value": str(job.get("id", ""))},
                    ],
                }],
                "MetadataOptions": {"HttpTokens": "required", "HttpPutResponseHopLimit": 1, "HttpEndpoint": "enabled"},
            }
            
            if KEY_NAME:
                params["KeyName"] = KEY_NAME
            if SPOT_ENABLED:
                params["InstanceMarketOptions"] = {
                    "MarketType": "spot",
                    "SpotOptions": {
                        "SpotInstanceType": "one-time",
                        "InstanceInterruptionBehavior": "terminate",
                        "MaxPrice": ""  # Use current Spot price
                    }
                }
            
            response = ec2.run_instances(**params)
            instance_id = response["Instances"][0]["InstanceId"]
            logger.info(f"Launched {instance_id} (type: {instance_type}) for job {job.get('id')}")
            
            # Emit CloudWatch metrics
            put_metric("GitHubRunners", "RunnerLaunched", 1, dimensions={
                "InstanceType": instance_type,
                "SpotEnabled": str(SPOT_ENABLED).lower()
            })
            
            return instance_id
            
        except Exception as e:
            last_error = e
            logger.warning(f"Failed to launch {instance_type}: {e}, trying next type...")
            continue
    
    # All instance types failed
    logger.error(f"Failed to launch runner for job {job.get('id')} with all instance types: {last_error}")
    raise last_error

def handler(event, context):
    """Handle SQS messages to launch runners."""
    results = {"launched": 0, "skipped": 0, "errors": 0}
    start_time = time.time()
    
    for record in event.get("Records", []):
        try:
            job = json.loads(record["body"])
            current_count = count_running_runners()
            
            # Emit metric for runner count
            put_metric("GitHubRunners", "ActiveRunners", current_count)
            
            if current_count >= RUNNERS_MAX:
                logger.warning(f"Runner limit reached ({current_count}/{RUNNERS_MAX}), skipping job {job.get('id')}")
                results["skipped"] += 1
                put_metric("GitHubRunners", "RunnersSkipped", 1, dimensions={"Reason": "MaxLimit"})
                continue
            
            launch_runner(job)
            results["launched"] += 1
            
        except Exception as e:
            logger.error(f"Error processing record: {e}", exc_info=True)
            results["errors"] += 1
            put_metric("GitHubRunners", "RunnerLaunchErrors", 1)
            # Don't raise - let DLQ handle retries
    
    # Emit processing time metric
    processing_time = time.time() - start_time
    put_metric("GitHubRunners", "ScaleUpProcessingTime", processing_time, unit="Seconds")
    
    logger.info(f"Scale-up completed: {results}")
    return {"statusCode": 200, "body": json.dumps(results)}
