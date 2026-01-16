"""Scale-Up Lambda - Launches EC2 runners."""
import base64
import json
import logging
import os
import time
import random
from datetime import datetime, timezone
import boto3
import urllib.request
import jwt

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
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

_github_app_config = None

def get_github_app_config():
    global _github_app_config
    if _github_app_config is None:
        response = secrets.get_secret_value(SecretId=SECRET_ARN)
        _github_app_config = json.loads(response["SecretString"])
    return _github_app_config

def generate_jwt():
    config = get_github_app_config()
    private_key = base64.b64decode(config["private_key"]).decode()
    now = int(time.time())
    payload = {"iat": now - 60, "exp": now + 600, "iss": config["app_id"]}
    return jwt.encode(payload, private_key, algorithm="RS256")

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
    response = ec2.describe_instances(Filters=[
        {"Name": "tag:Purpose", "Values": ["github-runner"]},
        {"Name": "instance-state-name", "Values": ["pending", "running"]},
    ])
    return sum(len(r.get("Instances", [])) for r in response.get("Reservations", []))

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
    registration_token = get_runner_registration_token()
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    runner_name = f"runner-{timestamp}-{job.get('id', 'unknown')}"
    labels = list(set(RUNNER_LABELS + job.get("labels", [])))
    user_data = generate_user_data(registration_token, labels, runner_name)
    
    params = {
        "ImageId": AMI_ID,
        "MinCount": 1,
        "MaxCount": 1,
        "SubnetId": random.choice(SUBNET_IDS),
        "SecurityGroupIds": SECURITY_GROUP_IDS,
        "UserData": user_data,
        "IamInstanceProfile": {"Arn": INSTANCE_PROFILE_ARN},
        "InstanceType": INSTANCE_TYPES[0],
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
        params["InstanceMarketOptions"] = {"MarketType": "spot", "SpotOptions": {"SpotInstanceType": "one-time", "InstanceInterruptionBehavior": "terminate"}}
    
    response = ec2.run_instances(**params)
    instance_id = response["Instances"][0]["InstanceId"]
    logger.info(f"Launched {instance_id} for job {job.get('id')}")
    return instance_id

def handler(event, context):
    for record in event.get("Records", []):
        job = json.loads(record["body"])
        if count_running_runners() >= RUNNERS_MAX:
            logger.warning("Runner limit reached")
            continue
        launch_runner(job)
    return {"statusCode": 200}
