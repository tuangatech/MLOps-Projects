import boto3
import json
import os

dynamodb = boto3.resource('dynamodb')
table_name = os.getenv('PREDICTION_TABLE_NAME', 'feedback-table')

def handler(event, context):
    table = dynamodb.Table(table_name)
    
    # Assume event contains "inference_id", "predicted_price"
    # TODO: Add actual_price of +7% above predicted_price to make the model performance degraded -> trigger retraining
    item = json.loads(event['body'])

    table.put_item(Item=item)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Logged successfully'})
    }