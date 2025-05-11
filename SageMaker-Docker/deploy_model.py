import boto3
import json
import time


def get_secret(secret_name):
    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

secrets = get_secret("sagemaker-deployment-secrets")
role_arn = secrets["SAGEMAKER_ROLE_ARN"]
ecr_image_uri = secrets["ECR_IMAGE_URI"]

# Variables
aws_account_id = boto3.client('sts').get_caller_identity()['Account']
aws_region = boto3.session.Session().region_name
model_name = "intent-detection-model"
endpoint_config_name = "intent-detection-endpoint-config"
endpoint_name = "intent-detection-endpoint"
instance_type = "ml.m5.large"

# Initialize clients
sagemaker_client = boto3.client('sagemaker', region_name=aws_region)
runtime_client = boto3.client('sagemaker-runtime', region_name=aws_region)

# Step 1: Create Model
sagemaker_client.create_model(
    ModelName=model_name,
    PrimaryContainer={"Image": ecr_image_uri},
    ExecutionRoleArn=role_arn,
)
print(f"> Role ARN: {role_arn}")
print(f"> ECR Image URI: {ecr_image_uri}")
print("> Model created.")

# Step 2: Create Endpoint Configuration
sagemaker_client.create_endpoint_config(
    EndpointConfigName=endpoint_config_name,
    ProductionVariants=[
        {
            "VariantName": "AllTraffic",
            "ModelName": model_name,
            "InstanceType": instance_type,
            "InitialInstanceCount": 1,
        }
    ],
)
print("> Endpoint configuration created.")

# Step 3: Create Endpoint
sagemaker_client.create_endpoint(
    EndpointName=endpoint_name,
    EndpointConfigName=endpoint_config_name,
)
print(f"> Endpoint creation started on {instance_type} instance.")

# Wait for endpoint to be ready
while True:
    describe_response = sagemaker_client.describe_endpoint(EndpointName=endpoint_name)
    status = describe_response["EndpointStatus"]
    if status == "InService":
        print("Endpoint is ready.")
        break
    elif status in ["Creating", "Updating"]:
        print("Waiting for endpoint to be ready...")
        time.sleep(30)
    else:
        raise Exception(f"Endpoint creation failed with status: {status}")

# Step 4: Invoke Endpoint
input_data = {"texts": ["What is the status of my order?", "Can I change my shipping address?"]}
payload = json.dumps(input_data)
response = runtime_client.invoke_endpoint(
    EndpointName=endpoint_name,
    ContentType="application/json",
    Body=payload,
)
result = json.loads(response["Body"].read().decode())
print("> Endpoint response:", result)