import json
import os
import uuid
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns', region_name='us-east-1')

TABLE_NAME    = os.environ['DYNAMODB_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
USER_EMAIL    = os.environ['USER_EMAIL']
GITHUB_REPO   = os.environ['GITHUB_REPO']
EXEC_REGION   = os.environ['EXEC_REGION']


def lambda_handler(event, context):
    # Write to DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    item_id = str(uuid.uuid4())
    table.put_item(Item={
        'id':        item_id,
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'region':    EXEC_REGION,
        'message':   f'Hello from {EXEC_REGION}!'
    })

    # Publish verification payload to Unleash live SNS
    sns_payload = {
        'email':  USER_EMAIL,
        'source': 'Lambda',
        'region': EXEC_REGION,
        'repo':   GITHUB_REPO
    }
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(sns_payload)
    )

    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'message': f'Hello from {EXEC_REGION}!',
            'region':  EXEC_REGION,
            'item_id': item_id
        })
    }
