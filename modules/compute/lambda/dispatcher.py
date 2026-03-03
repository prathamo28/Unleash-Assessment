import json
import os
import boto3

ecs = boto3.client('ecs')

ECS_CLUSTER_ARN = os.environ['ECS_CLUSTER_ARN']
TASK_DEF_ARN    = os.environ['TASK_DEF_ARN']
SUBNET_ID       = os.environ['SUBNET_ID']
SG_ID           = os.environ['SG_ID']
EXEC_REGION     = os.environ['EXEC_REGION']


def lambda_handler(event, context):
    response = ecs.run_task(
        cluster=ECS_CLUSTER_ARN,
        taskDefinition=TASK_DEF_ARN,
        launchType='FARGATE',
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets':        [SUBNET_ID],
                'securityGroups': [SG_ID],
                'assignPublicIp': 'ENABLED'
            }
        }
    )
    tasks = response.get('tasks', [])
    task_arn = tasks[0]['taskArn'] if tasks else 'none'
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'message':  f'ECS task dispatched from {EXEC_REGION}',
            'region':   EXEC_REGION,
            'task_arn': task_arn
        })
    }
