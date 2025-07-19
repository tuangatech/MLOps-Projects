import boto3
import json
import os

sagemaker_runtime = boto3.client('sagemaker-runtime')

ENDPOINT_NAME = os.getenv('SAGEMAKER_ENDPOINT_NAME', 'your-endpoint-name')

def handler(event, context):
    # Example payload: {"data": [[1200, 3, 2, ...]]}
    body = json.loads(event['body'])
    payload = json.dumps(body)

    response = sagemaker_runtime.invoke_endpoint(
        EndpointName=ENDPOINT_NAME,
        ContentType='application/json',
        Body=payload
    )

    prediction = json.loads(response['Body'].read().decode())
    return {
        'statusCode': 200,
        'body': json.dumps({'prediction': prediction})
    }