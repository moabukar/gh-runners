"""Scale-Down Lambda - Terminates idle runners."""
import json
import logging
import os
from datetime import datetime, timezone, timedelta
import boto3

PREFIX = os.environ["PREFIX"]
MIN_RUNNING_TIME_MINS = int(os.environ.get("MIN_RUNNING_TIME_MINS", "5"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

ec2 = boto3.client("ec2")
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

def handler(event, context):
    """Terminate stale or orphaned runner instances."""
    try:
        paginator = ec2.get_paginator("describe_instances")
        terminated = []
        skipped = []
        
        now = datetime.now(timezone.utc)
        min_running = timedelta(minutes=MIN_RUNNING_TIME_MINS)
        max_runtime = timedelta(hours=4)
        
        for page in paginator.paginate(Filters=[
            {"Name": "tag:Purpose", "Values": ["github-runner"]},
            {"Name": "instance-state-name", "Values": ["pending", "running"]},
        ]):
            for reservation in page.get("Reservations", []):
                for instance in reservation.get("Instances", []):
                    instance_id = instance["InstanceId"]
                    running_time = now - instance["LaunchTime"]
                    
                    # Skip instances that haven't been running long enough
                    if running_time < min_running:
                        skipped.append(instance_id)
                        continue
                    
                    # Terminate instances exceeding max runtime
                    if running_time > max_runtime:
                        try:
                            ec2.terminate_instances(InstanceIds=[instance_id])
                            terminated.append(instance_id)
                            logger.info(f"Terminated {instance_id} - exceeded max runtime ({running_time})")
                        except Exception as e:
                            logger.error(f"Failed to terminate {instance_id}: {e}")
        
        result = {
            "terminated": len(terminated),
            "terminated_ids": terminated,
            "skipped": len(skipped)
        }
        logger.info(f"Scale-down completed: {result}")
        return {"statusCode": 200, "body": json.dumps(result)}
        
    except Exception as e:
        logger.error(f"Error in scale-down handler: {e}", exc_info=True)
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
