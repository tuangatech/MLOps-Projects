# Deploying a Model from Jupyter Notebook to AWS using Docker and SageMaker

A lot of us start building ML models in Jupyter Notebooks - whether it's on Google Colab, Kaggle, or a local computer. It's a great setup for prototyping and testing ideas quickly. But if you want to turn that model into something people can actually use in the real world, you need to get it out of the notebook and into a proper production environment.

In this article, I'll show you how I deployed an [intent detection model](https://github.com/tuangatech/NLP-Projects/tree/main/Intent%20Detection%20w%20RoBERTa) (built with RoBERTa and PyTorch) to AWS using Docker and SageMaker. The goal is to turn that local model into a real-time API that's scalable, reliable, and ready for production. If you're looking to take your ML projects one step closer to production, this guide is for you.


### Solution Overview

I decided to choose the custom Docker container approach using Amazon SageMaker. This method helps me control over the runtime environment, dependencies, and model inference logic, making it more flexible and reliable than pre-built SageMaker containers. I actually tried the pre-built route first, but ran into significant challenges to just install additional dependencies correctly. After lots of effort, the deployment failed with an `Unknown exception` from `org.pytorch.serve.wlm.WorkerThread`. At that point, I pivoted to build my own container. Way smoother experience.

Here are the 7 key steps in the process:
1. Prepare Code and Dependencies: Set up files like `inference.py`, `Dockerfile`, `requirements.txt`, `serve.py` for packaging and serving the model.
2. Set Up AWS Infrastructure: Use Terraform to create an IAM role, an ECR repository and 2 secret values.
3. Build a Custom Docker Image: Package the model and inference logic into a Docker image.
4. Test Locally and Push to ECR : Validate the container locally before pushing to AWS ECR.
5. Deploy to SageMaker and Test It: Use the SageMaker SDK to create a model, configure the endpoint, and deploy it.
6. Perform Latency and Performance Testing: Simulate production scenarios to evaluate response times.
7. Clean up Resources: Tear down the endpoint and supporting infrastructure to avoid ongoing charges.

In this article, I won't walk through the AWS Console - no clicking Elastic Container Service, no "hit the Create Repository button" kind of stuff.  The UI changes too often anyway. Instead, we will do this the dev-friendly way: using **AWS CLI**, **Terraform**, and **Python with the SageMaker SDK**. This code-first setup is way more reliable, easier to automate, and just fits better with real-world workflows.

One common fear for us getting into AWS is that the free tier won't make anything close to production, and going past it will drain your wallet. Don't worry, I'll show you how to keep costs low while still building something solid. And like any good software setup, we don't want to hardcode secrets or sensitive info - I'll also cover how to keep things secure and avoid common mistakes.

**AWS Services Used**
1. SageMaker: Deploy and host the Intent detection model as a real-time API
2. Identity and Access Management (IAM): Manage roles and permissions for SageMaker, ECR and CloudWatch
3. Elastic Container Registry (ECR): Store both the base SageMaker image (public) and my custom Docker image (private)
4. Secrets Manager: Store 2 secret values
5. CloudWatch: Capture logs for debugging


### Step 1: Prepare Code and Dependencies
To deploy the model to SageMaker using a custom container, the first step is to prepare the necessary code, logic, and environment configuration.

1. Adapt Inference Code for SageMaker Compatibility
Create an `inference.py` file that contains the core inference logic, refactored to work with SageMaker’s container serving conventions. Specifically, implement the following required functions:
- `model_fn(model_dir)` – returns the trained model and label encoder from a specific directory
- `input_fn(input_data, content_type)` – processes incoming requests
- `predict_fn(texts, artifacts)` – performs inference using model and preprocessed input
- `output_fn(prediction, accept)` – formats and return the prediction

These functions form the interface between SageMaker's runtime and our model logic.

2. Prepare a Custom Dockerfile
Created a `Dockerfile` based on the official Amazon SageMaker PyTorch inference image. This base image ensures compatibility with SageMaker endpoints. The Dockerfile installs the inference code, required packages, and sets up the entry point for serving.

3. Update Python Dependencies
There are two different `requirements.txt` files to consider in this solution — one for your **local development environment**, and one for the **Docker image used in SageMaker**. Each serves a different purpose:
- Local `requirements.txt` (used when running `deploy_model.py` and `test_endpoint.py` from your machine)
  - Add `boto3` to interact with AWS services such as SageMaker, S3, and STS.
  - Add `flask` to serve as a lightweight web server at local.
- Docker `requirements.txt` (included in the Docker container that will run on SageMaker):
  - Only list the packages required for **inference**.
  - You do not need to include `torch` as we're using a base image `pytorch-inference:2.2.0-gpu`, since that library is already bundled.

4. Create a Container Entry Point (`serve.py`)
Implement a `serve.py` script as the container’s entry point. This script launches an HTTP server that handles:
- `POST /invocations` – For inference requests, delegating processing to functions in `inference.py`.
- `GET /ping` – For health checks to confirm the container is running and ready to serve traffic.

This structure ensures the container can communicate effectively with the SageMaker platform during inference.

5. Other Files
- `model.pth`: trained PyTorch model weights.
- `model.py`: model architecture definition.
- `label_encoder.pkl`: serialized object for encoding/decoding labels.
- `utils.py`: utility functions
- `main.tf`: a Terraform configuration file used to define and provision AWS infrastructure as code.
- `deploy_model.py`: automate the deployment of the Docker-based model to SageMaker
- `test_local.py`: test the Docker container locally
- `test_endpoint.py`: test the deployed SageMaker endpoint after deployment.
- `test_latency.py`: test with real-life scenarios to find out responses' latency


### Step 2: Set Up AWS Infrastructure

Before we can deploy anything with SageMaker, we need to take care of some setup - mostly permissions and a place to store our Docker image. Instead of clicking through the AWS Console, we'll use Terraform to spin up the required infrastructure as code. That way, it's repeatable, version-controlled, and easy to tweak later.

Firstly, we need an IAM role that SageMaker can assume. In Terraform, that's just an `aws_iam_role` block and we allow SageMaker (`sagemaker.amazonaws.com`) to use it. This role will need access to pull images from ECR, write logs to CloudWatch, and do all the usual SageMaker stuff.

For this demo, I gave the role full access to ECR, SageMaker, and CloudWatch (just to keep things simple). But heads up - in production, you should definitely tighten that down and follow **least privilege** best practices.

Next, we need to set up an ECR repo where we'll push our custom Docker image.

Drop all of this into a `main.tf` file and let Terraform do the job.

```json
...
# Attach SageMaker Full Access Policy
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Output the Role ARN
output "sagemaker_role_arn" {
  value = aws_iam_role.sagemaker_role.arn
}

# Create an ECR repository
resource "aws_ecr_repository" "intent_detection_model_repo" {
  name = "intent-detection-model"
  image_tag_mutability = "MUTABLE" # Optional: Allows tags to be mutable
  
  image_scanning_configuration {
    scan_on_push = true # Automatically scans images for vulnerabilities
  }
}

# Output the ECR repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.intent_detection_model_repo.repository_url
}
```

After successfully running the Terraform commands below, the terminal will output two values:
- `sagemaker_role_arn`: The IAM role ARN for SageMaker permissions.
- `ecr_repository_url`: The ECR URI for your model’s Docker image.

These values are sensitive and **must not** be hardcoded in `deploy_model.py` — especially if committing all files to a public repository in my case. What we should do instead:
- `main.tf` saves both values to **AWS Secrets Manager**, encrypting them at rest.
- `deploy_model.py` fetches these values at runtime from Secrets Manager, no hardcode at all.

Open a `Bash` terminal to initialize Terraform, then apply the configuration.

```bash
terraform init   # Sets up Terraform
terraform plan   # Preview changes
terraform apply  # Deploy resources
```

After that, we have our **IAM role**, **ECR repo**, and **secrets** ready to use in the next steps.

### Step 3: Build a Custom Docker Image

1. Dockerfile

The Dockerfile defines how to build a Docker image that packages your model, inference code, and dependencies for deployment on Amazon SageMaker. Let's breakdown what it does:

- I pull the base image from an official AWS Deep Learning Container for PyTorch inference on SageMaker, which includes optimized support for GPU, Python 3.10, and CUDA 11.8. This ensures compatibility with SageMaker’s hosting environment. A full list of supported images is available on [AWS' Available Deep Learning Containers Images](https://github.com/aws/deep-learning-containers/blob/master/available_images.md?spm=a2ty_o01.29997173.0.0.2a4c51719NiRCF&file=available_images.md).
```
FROM 763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.2.0-gpu-py310-cu118-ubuntu20.04-sagemaker
```
- Copies the `requirements.txt` file from the same directory to the container, then to intall the Python packages listed in `requirements.txt`. The `--no-cache-dir` option helps reduce image size.

```docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

- Copies the model artifacts and related Python scripts into the container.
- Copies serve.py, which handle SageMaker’s inference and health check requests at `/invocations` and `/ping` endpoints.
- Specifies the command to run when the container starts, it executes `python serve.py` to listen for incoming inference requests from SageMaker.

2. Prepare for Docker Image Build

Before building the Docker image, let's set some variables that we will use later.

```bash
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ENDPOINT_NAME=intent-detection-endpoint
ENDPOINT_CONFIG_NAME=intent-detection-endpoint-config
MODEL_NAME=intent-detection-model
```

In the first line of the Dockerfile, we pull a base image from 763104351884, which is Amazon’s public ECR repository for SageMaker inference containers. Therefore, we must authenticate to two ECR repositories:
- Amazon's public ECR (763104351884) to pull the base container.
- Your own private ECR ($AWS_ACCOUNT_ID) to push your custom image.

```bash
# Login to AWS's container repository `763104351884`
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 763104351884.dkr.ecr.us-east-1.amazonaws.com

# Login to my ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

3. Build the Docker image

```bash
# docker build --no-cache -t intent-detection-model . 
# docker buildx build --no-cache --platform=linux/amd64 -t intent-detection-model . # output OCI format
docker build --no-cache --provenance=false \
  -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$MODEL_NAME:latest .
```

Here's what each part of the command does:
- `docker build`: This is the command to build a new Docker image.
- `--no-cache`: build the image from scratch without using any cached layers from previous builds
- `--provenance=false`: Disables BuildKit provenance metadata in the image. Disabling it helps avoid issues with AWS SageMaker that doesn’t support extended metadata.
- `-t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$MODEL_NAME:latest .`: Tags the image with your ECR repository URI where Docker will push the image to.
- `.`: Specifies the build context, which is the current directory (.), where Docker looks for the Dockerfile.


### Step 4: Test Locally and Push the Docker Image

1. Local testing of Docker Container
After building the Docker image locally, it’s a good practice to test the container before pushing it to ECR and deploying it on SageMaker. This helps you validate that the container starts successfully, the inference endpoint is exposed and the `inference.py` logic correctly processes input and returns output. Trust me, this step might take you some time on your first run but it's far less time-consuming than debugging issues after deployment in SageMaker.

Open a **new `CMD` window** to run the docker container as a web server. Use `Ctrl + C` to stop the server when done.
```bash
docker run -it --rm -p 8080:8080 intent-detection-model
```

This maps container port 8080 to your local machine so you can send requests to it. Leave this running - it's your local inference server.

In the `Bash` terminal, we run `test_local.py`. This script sends inference requests with two sample texts "What is the status of my order?" and "Can I change my shipping address?".

```bash
source venv/Scripts/activate
python test_local.py
```

```
Status Code: 200
Prediction result:
{
  "intents": [
    "track_order",
    "change_shipping_address"
  ]
}
```

If the container responds with the correct intents, it confirms that the model and inference logic are working properly in a Dockerized environment. And we are ready for the next step.

2. Push the custom Docker image to ECR repository

```bash
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$MODEL_NAME:latest
```

Now the image is ready for SageMaker to pull and deploy.

### Step 5: Deploy to SageMaker and Test It
Time to bring the model online. Run:

```bash
python deploy_model.py
```

Here’s what that script does under the hood:

- Get secret values of Role ARN and ECR Image URI from Secrets Manager. These 2 values were saved by Terraform in Step 2.
    ```python
    secrets = get_secret("sagemaker-deployment-secrets")
    role_arn = secrets["SAGEMAKER_ROLE_ARN"]
    ecr_image_uri = secrets["ECR_IMAGE_URI"]
    ```

- Create a SageMaker model named `intent-detection-model` using the Docker image stored in ECR and the IAM role we created earlier to access AWS services.
    ```python
    sagemaker_client.create_model(
        ModelName=model_name,
        PrimaryContainer={"Image": ecr_image_uri},
        ExecutionRoleArn=role_arn,
    )
    ```
- Creates an endpoint configuration named `intent-detection-endpoint-config`. This configuration references the `intent-detection-model` and specifies the instance type `ml.m5.large`, a cost-effective CPU option suitable for testing purposes, with a single instance.
    ```python
    sagemaker_client.create_endpoint_config(
        EndpointConfigName=endpoint_config_name,
        ProductionVariants=[
            {
                "VariantName": "AllTraffic",
                "ModelName": model_name,
                "InstanceType": "ml.m5.large",
                "InitialInstanceCount": 1,
            }
        ],
    )
    ```
- Deploys the model as a real-time HTTPS API named `intent-detection-endpoint` using the configuration. SageMaker provisions the instance, loads the Docker container, and starts the model server.
    ```python
    sagemaker_client.create_endpoint(
        EndpointName=endpoint_name,
        EndpointConfigName=endpoint_config_name,
    )
    ```
- Waits for the endpoint to become active. This usually takes a few minutes (around 8 minutes in my case).
- Sends a test request using a sample JSON payload to validate that the endpoint is live and serving predictions correctly. Response from the endpoint will be printed out to the terminal.
    ```python
    input_data = {"texts": ["What is the status of my order?", "Can I change my shipping address?"]}
    payload = json.dumps(input_data)
    response = runtime_client.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType="application/json",
        Body=payload,
    )
    result = json.loads(response["Body"].read().decode())
    ```

If you want to test other examples? Modify `test_endpoint.py` and rerun. You're now running real-time inference from your custom Docker model on AWS.

**Amazon CloudWatch**

I added several logs in `inference.py` and `deploy_model.py`. These logs are captured and stored in Amazon CloudWatch, which is an essential tool for monitoring, debugging, and verifying predictions when deploying SageMaker models.

To view logs in AWS Management Console,go to CloudWatch > Log groups > /aws/sagemaker/Endpoints/intent-detection-endpoint

⚠️ Heads up: By default, CloudWatch keeps logs forever, which isn't great if you're trying to stay within budget. For side projects, I usually switch log retention to 1 week. Just click "Edit retention settings" on the log group and pick something reasonable for you.

### Step 6: Perform Latency and Performance Testing

Testing latency and performance of your SageMaker model endpoint is essential for any production system:
- Many applications have specific SLA requirements and users expect responses within seconds.
- If your instance type can process 1,000 texts in 10 seconds, you might be over-provisioned. You could save money by scaling down - but only if you know your baseline performance. Don't overpay!
- I tried sending 500 texts and got a read-timeout error. For more realistic performance testing, try throwing in a big batch like 10,000 texts and see when the system starts choking. But if 10,000 texts is close to your real workload, make sure to:
  - increase the timeout setting
  - and think about autoscaling to handle peak traffic.
- You may want to check which batch size is optimal.

```bash
python test_latency.py
```

```
Batch size 1: 0.73 seconds
Batch size 10: 2.10 seconds
Batch size 50: 8.33 seconds
Batch size 500: <timeout error> 
```

Let's take a real-world example: In customer service, if your intent detection takes more than 2 seconds, people might get frustrated and hang up. Now imagine holiday season traffic - 10x the usual load, and they still want fast replies. Performance testing helps you tune your endpoint config and scaling strategy so you're not flying blind. It's all about finding the balance between cost and responsiveness for your specific use case.


### Step 7: Clean Up Resources 🧹
Once you’re done testing, don’t forget to shut stuff down—especially your SageMaker endpoint. I once left a GPU instance (we pay by hours) running over a 4-day business trip and … "boom".

Here’s a checklist of what you should consider cleaning up:

1. Delete the SageMaker Endpoint, Endpoint Configuration and Model: 

SageMaker Endpoint is the most expensive resource in this solution. SageMaker endpoint is billed by the hour based on the instance type and count, even if it’s idle. So delete in order Endpoint - Endpoint config - Model. Use `list-endpoints` to make sure nothing’s hanging around.

```bash
aws sagemaker delete-endpoint --endpoint-name $ENDPOINT_NAME

# Make sure no endpoints running
aws sagemaker list-endpoints

# Delete endpoint configuration
aws sagemaker delete-endpoint-config --endpoint-config-name $ENDPOINT_CONFIG_NAME

# Delete model
aws sagemaker delete-model --model-name $MODEL_NAME
```

2. Delete the ECR Image (Optional) 

If you're no longer using the Docker image, consider deleting it from ECR to free up storage and avoid future confusion:
```bash
# List image details
aws ecr describe-images --repository-name intent-detection-model

# Delete image
aws ecr batch-delete-image --repository-name intent-detection-model \
    --image-ids imageTag=latest
```

3. Review CloudWatch Log Retention

CloudWatch logs are cheap, but they can accumulate over time. If you set logs to never expire, they may eventually incur noticeable charges, especially in high-traffic or experimental environments. We once did an experiment with OpenSearch Serverless and stored logs into CloudWatch, which accidentally ended up 300GB/day and led to $10,000+ just for log charges. Set a reasonable retention period (like 1 week) so you’re not storing logs forever for no reason.

4. How to Ensure You're Not Incuring Extra Charges 💰

You can access Cost Explorer to track current charges. Look for any unexpected charges under SageMaker, ECR, CloudWatch, etc.

Additionally, you can set up an AWS Budget to help monitor and control costs:
- Define a threshold for overall AWS usage, like `$10/month`.
- Configure alerts to notify you when you're approaching or exceeding your budget.
- Access this via the AWS Billing Console > Budgets.

 TL;DR: Be like a smart dev: spin stuff up, test what you need, then burn it all down. Saves cash, saves stress, and keeps your AWS account clean and lean.


### Summary
This walkthrough shares the exact approach I use to get my intent detection models deployed smoothly on SageMaker without any clicks. Here’s the big picture of what we did:
1. Built the infra with Terraform - it’s all codified, versioned, and repeatable.
2. Dockerized the model – everything bundled into a custom container so it runs exactly how we expect on SageMaker, no dependency mismatches or "but it worked on my machine" issues.
3. Tested locally first – verified the model actually works in a container before throwing it into the cloud (trust me, this saves a ton of debug time).
4. Deployed with Python + SDK – created the model, endpoint config, and endpoint itself via code. That means automation-ready, CI/CD-friendly, and zero UI clicks.
5. Logged to CloudWatch – helpful during early deployment and debugging.
6. Performance tested – because real-world traffic isn’t always nice and slow. We stress-tested the endpoint to understand its limits and figure out when autoscaling might kick in.
7. Cleaned up properly – endpoints, images, logs, billing alerts. The boring stuff that saves you real money.

Give it a try on your own model. Once you’ve completed it, you can plug this flow into pretty much any ML project with minimal tweaks.