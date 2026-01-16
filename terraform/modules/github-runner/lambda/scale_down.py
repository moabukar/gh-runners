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
    response = ec2.describe_instances(Filters=[
        {"Name": "tag:Purpose", "Values": ["github-runner"]},
        {"Name": "instance-state-name", "Values": ["pending", "running"]},
    ])
    
    terminated = 0
    now = datetime.now(timezone.utc)
    min_running = timedelta(minutes=MIN_RUNNING_TIME_MINS)
    max_runtime = timedelta(hours=4)
    
    for reservation in response.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            running_time = now - instance["LaunchTime"]
            if running_time > max_runtime:
                ec2.terminate_instances(InstanceIds=[instance["InstanceId"]])
                logger.info(f"Terminated {instance['InstanceId']} - exceeded max runtime")
                terminated += 1
    
    return {"statusCode": 200, "body": json.dumps({"terminated": terminated})}
