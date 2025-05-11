import time
import statistics
import boto3
import json
import logging
import traceback


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

aws_region = boto3.session.Session().region_name
endpoint_name = "intent-detection-endpoint"

runtime_client = boto3.client('sagemaker-runtime', region_name=aws_region)

batch_sizes = [1, 10, 50, 100]
latencies = {}

for size in batch_sizes:
    # Create a batch of the specified size
    batch = ["I need help with my order"] * size
    payload = json.dumps({"texts": batch})
    
    # Measure response time
    start_time = time.time()
    response = runtime_client.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType="application/json",
        Body=payload,
    )
    end_time = time.time()
    
    latencies[size] = end_time - start_time
    logger.info(f"Batch size {size}: {latencies[size]:.2f} seconds")
    # print(f"Batch size {size}: {latencies[size]:.2f} seconds")

# Calculate average processing time per item
per_item = {size: latencies[size]/size for size in batch_sizes}
# print(f"Average processing time per item: {statistics.mean(per_item.values()):.2f} seconds")
logger.info(f"Average processing time per item: {statistics.mean(per_item.values()):.2f} seconds")