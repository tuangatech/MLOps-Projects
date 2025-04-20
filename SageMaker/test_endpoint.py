import boto3
import json

aws_region = boto3.session.Session().region_name
endpoint_name = "intent-detection-endpoint"

runtime_client = boto3.client('sagemaker-runtime', region_name=aws_region)
# Step 4: Invoke Endpoint
input_data = {
    "texts": [
        "I have a problem with cancelling an order I made", 
        "I am trying to talk with bloody customer assistance",
        "could you help me checking what options for delivery I have?"
    ]
}
payload = json.dumps(input_data)
response = runtime_client.invoke_endpoint(
    EndpointName=endpoint_name,
    ContentType="application/json",
    Body=payload,
)
result = json.loads(response["Body"].read().decode())
print("Endpoint response:", result)
