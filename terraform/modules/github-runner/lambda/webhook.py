"""Webhook Lambda - Receives GitHub workflow_job events."""
import hashlib
import hmac
import json
import logging
import os
import boto3

SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]
SECRET_ARN = os.environ["SECRET_ARN"]
RUNNER_LABELS = set(os.environ.get("RUNNER_LABELS", "self-hosted").split(","))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

sqs = boto3.client("sqs")
secrets = boto3.client("secretsmanager")
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

_webhook_secret = None

def get_webhook_secret():
    global _webhook_secret
    if _webhook_secret is None:
        response = secrets.get_secret_value(SecretId=SECRET_ARN)
        _webhook_secret = json.loads(response["SecretString"])["webhook_secret"]
    return _webhook_secret

def verify_signature(payload, signature):
    if not signature or not signature.startswith("sha256="):
        return False
    secret = get_webhook_secret()
    expected = "sha256=" + hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)

def handler(event, context):
    body = event.get("body", "")
    if event.get("isBase64Encoded"):
        import base64
        body = base64.b64decode(body).decode()
    
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    
    if not verify_signature(body.encode(), headers.get("x-hub-signature-256", "")):
        return {"statusCode": 401, "body": "Invalid signature"}
    
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": "Invalid JSON"}
    
    if headers.get("x-github-event") != "workflow_job":
        return {"statusCode": 200, "body": "Ignored"}
    
    action = payload.get("action", "")
    job = payload.get("workflow_job", {})
    job_labels = set(job.get("labels", []))
    
    if action != "queued" or not RUNNER_LABELS.intersection(job_labels):
        return {"statusCode": 200, "body": "Ignored"}
    
    message = {
        "id": job.get("id"),
        "run_id": job.get("run_id"),
        "name": job.get("name"),
        "labels": list(job_labels),
        "repository": payload.get("repository", {}).get("full_name"),
        "org": payload.get("organization", {}).get("login"),
    }
    
    sqs.send_message(QueueUrl=SQS_QUEUE_URL, MessageBody=json.dumps(message))
    logger.info(f"Queued job {job.get('id')}")
    return {"statusCode": 200, "body": "Queued"}
