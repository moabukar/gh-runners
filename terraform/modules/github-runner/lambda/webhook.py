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
    """Handle GitHub webhook events."""
    request_id = context.aws_request_id if context else "unknown"
    logger.info(f"[{request_id}] Processing webhook event")
    
    try:
        body = event.get("body", "")
        if event.get("isBase64Encoded"):
            import base64
            body = base64.b64decode(body).decode()
        
        headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
        github_event = headers.get("x-github-event", "")
        github_delivery = headers.get("x-github-delivery", "unknown")
        
        logger.info(f"[{request_id}] Event: {github_event}, Delivery: {github_delivery}")
        
        if not verify_signature(body.encode(), headers.get("x-hub-signature-256", "")):
            logger.warning(f"[{request_id}] Invalid webhook signature for delivery {github_delivery}")
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "Invalid signature", "request_id": request_id})
            }
        
        try:
            payload = json.loads(body)
        except json.JSONDecodeError as e:
            logger.error(f"[{request_id}] Invalid JSON in webhook: {e}", exc_info=True)
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Invalid JSON", "request_id": request_id, "details": str(e)})
            }
        
        if github_event != "workflow_job":
            logger.debug(f"[{request_id}] Ignoring event type: {github_event}")
            return {"statusCode": 200, "body": json.dumps({"message": "Ignored", "event": github_event})}
        
        action = payload.get("action", "")
        job = payload.get("workflow_job", {})
        job_id = job.get("id")
        job_labels = set(job.get("labels", []))
        repository = payload.get("repository", {}).get("full_name", "unknown")
        
        logger.info(f"[{request_id}] Job {job_id} action={action}, repo={repository}, labels={job_labels}")
        
        if action != "queued" or not RUNNER_LABELS.intersection(job_labels):
            logger.debug(f"[{request_id}] Job {job_id} ignored: action={action}, matching_labels={RUNNER_LABELS.intersection(job_labels)}")
            return {
                "statusCode": 200,
                "body": json.dumps({"message": "Ignored", "reason": "action_or_labels"})
            }
        
        message = {
            "id": job_id,
            "run_id": job.get("run_id"),
            "name": job.get("name"),
            "labels": list(job_labels),
            "repository": repository,
            "org": payload.get("organization", {}).get("login"),
        }
        
        sqs.send_message(QueueUrl=SQS_QUEUE_URL, MessageBody=json.dumps(message))
        logger.info(f"[{request_id}] Queued job {job_id} for repository {repository}")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Queued",
                "job_id": job_id,
                "request_id": request_id
            })
        }
        
    except Exception as e:
        logger.error(f"[{request_id}] Error processing webhook: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Internal server error",
                "request_id": request_id,
                "type": type(e).__name__
            })
        }
