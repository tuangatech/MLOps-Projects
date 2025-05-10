# End-to-End ML Deployment with MLflow, FastAPI, and AWS Fargate
In this project, I walk through how to train, track, and deploy a machine learning model using a modern MLOps stack — combining XGBoost, MLflow, FastAPI, and AWS ECS with Fargate. The goal is to build a regression model that predicts the median house value of a California block group based on features like income level, house age, number of rooms, and geographic location. I use XGBoost for its strong performance on tabular data and MLflow to track training runs, log metrics, and register the trained model for deployment. 

Once the model is trained and registered in MLflow, I use FastAPI to create a simple web service that exposes a`/predict` endpoint for real-time inference. To deploy this service in a scalable and serverless way, I containerize the application with Docker and run it on AWS ECS with Fargate, which handles infrastructure management without needing to provision EC2 instances. 

This end-to-end solution demonstrates a practical approach to deploying ML models in production with a clean, reproducible workflow. It’s particularly useful for developers and data scientists who want a minimal yet scalable setup without diving deep into Kubernetes or setting up custom inference servers.

### High-Level Approach
In this project, we aim for a clean and scalable deployment of a machine learning model using tools and best practices below.

1. The trained model will be downloaded from S3 bucket **at runtime** instead of baking it into the Docker image. Hence, updating the model becomes much simpler—you don’t have to rebuild or redeploy the Docker image every time there's a change. It also allows us to rollback easily, which is a big deal for production reliability. Since our XGBoost model is small (only around 7MB), the cold start impact from downloading it dynamically is negligible.

2. We use **MLFlow** to keep track of our experiments and manage different model versions without relying on manual notes. It logs all the important details like training parameters, evaluation metrics, and generated artifacts (e.g., plots or confusion matrices). Additionally, MLFlow's model registry helps us manage model versions properly, and we know which one to roll forward or backward when needed.

3. **FastAPI** is a better choice than Flask for serving ML models as it has built-in async support, which can handle multiple inference requests concurrently without blocking. That’s a big win if you're deploying in a production environment with real-time traffic. It also offers automatic input validation with Pydantic and auto-generates interactive API docs (Swagger). 

4. I use **AWS ECS with Fargate** to deploy the FastAPI app. This setup lets me run containers in a serverless way — meaning we don’t have to manually provision or manage EC2 instances (VMs). Fargate only charges for the compute we actually use, which keeps costs down, and it supports features like auto-scaling (even though we’re not using that part yet). Our containers run inside a VPC and can assume IAM roles, so security and networking are well-contained. 

5. I use **Terraform** to setup AWS infrastructure which treats infrastructure as code. We can describe everything — VPCs, load balancers, ECS tasks, etc. — in configuration files, which can be committed to version control and reused across environments. It also makes deployments reproducible and easier to automate through CI/CD pipelines.

**Why This Matters**
- Security: VPC + IAM enforce least-privilege access.
- Scalability: Fargate + ALB handle traffic spikes.
- Cost-Efficiency: Pay only for running containers (Fargate).
- ==== rollout and rollback easily ??

### Local Development
The main purpose of this project is not about training a model so I pick a simple dataset of California housing value. Try to build a MLOps pipeline : Train → Evaluate → Log → Register → Store.

1. XGBoost
- Load the dataset from sklearn and filter out some outliers datapoints.
- Tune hyperparameters of XGBRegressor using RandomSearchCV with 30 random combinations and 5-fold cross-validation.
- Finds the best hyperparameters that minimize prediction error
- Evaluate the model on test data and Calculates RMSE and MAE (accuracy metrics)

2. MLFlow
- Log Everything with MLflow: best parameters, evaluation metrics, the trained model, feature importance plot, true vs predicted values plot
- Register the best model in MLflow under the name "california-housing" for version control.
- The best model is exported and uploaded to an Amazon S3 bucket for storage and later deployment in serving phase.

3. FastAPI app
- This FastAPI app serves as a model inference API.
- Get S3 bucket and path from environment variables that are set in Terraform for ECS deployment.
- Loads the MLflow model directly from S3
- Provide 3 endpoints:
  - `GET /health`: Returns "healthy" if the app is running (liveness check)
  - `GET /ready`: Checks if the model is loaded and working (readiness check). Also runs a sample prediction to validate functionality.
  - `POST /predict`: Accepts housing data → returns predicted price using loaded model.

### Model Packaging
1. Dockerize the FastAPI app
- Build with the official slim Python 3.11 image
- Copy requirements.txt first so Docker can cache this layer. If the dependencies don’t change, we skip reinstalling them every time.
- Always use `--no-cache-dir` in production Dockerfiles, we have smaller image containing only installed packages.
- Copy the main.py to app folder in the container.
- Tell Docker to check if the app is ready by hitting `/ready` every 30 seconds.
- Run the FastAPI app using Uvicorn.

2. Local Testing First

Before deploying your FastAPI app in a Docker container or to production, always test it locally. This helps catch common issues early, such as:
- Missing or incompatible dependencies
- Incorrect file paths when copying files into the Docker image
- MLFlow model loading failures
- Permission issues with temp folders or local storage
- Misconfigured API endpoints
- Input parsing logic in `predict` endpoint

By testing locally, you can avoid wasting time debugging these problems inside a container.

a. Test FastAPI Application Locally

Start by running the FastAPI app (main.py) directly using Uvicorn to verify everything works outside of Docker.

```bash
# Navigate to the app directory and run the server
cd app
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Once the server is running, open your browser and go to http://localhost:8000/ready This endpoint should return a simple response confirming that the app has started and the model is loaded successfully (e.g., `{"status": "ready"}`). You can also try hitting endpoints like `/predict` using tools like curl, Postman, or Swagger UI at http://localhost:8000/docs.

b. Test Docker Image Locally

Once your app runs find locally, we can build and test it in a Docker container to simulate the real deployment environment. We build the image and run the container to map port 80 inside the container to port 8000 on our local machine. (I actually updated file `build_push_docker.sh` to build docker image)

```bash
cd docker
docker build -t my-fastapi-app .  
docker run -p 8000:80 my-fastapi-app
```

Once again, we open browser and go to http://localhost:8000/ready and check the response. If this works, it means dependencies were installed properly and the app starts up successfully inside the container. Now, the image is ready to be uploaded to ECR.

3. Build and Push Docker image to ECR

A bash script `build_push_docker.sh` is created to:
- Build and tag a Docker image
- Login Amazon ECR and push that Docker image to ECR.

Actually, we need to have ECR repo created first (by terraforms in the next section), then we can push the Docker image to ECR.


### AWS Infrastructure Setup (Terraform-based)

**1. `vpc.tf` – Virtual Private Cloud & Subnet Setup**

Defines the core networking for your app. Even if your FastAPI app is public-facing, it still runs inside a VPC for security and scalability. This setup includes:
- A VPC
- Two public subnets in different Availability Zones for high availability
- An Internet Gateway
- A public route table and subnet associations

Production should always span at least two AZs for failover and load balancing. ALBs require it.

**2. `ecr.tf` – Docker Registry**

This file creates an Amazon ECR repository where you'll push your FastAPI Docker image to, for ECS to pull and run. You can think of ECR as a private Docker Hub, fully managed by AWS and integrated with IAM and ECS.

**3. `iam.tf` – IAM Roles for ECS**

Sets up roles and permissions:
- Execution role for ECS to pull images and write logs
- Task role for your app to access AWS services like S3 or CloudWatch

**4. `ecs.tf` – ECS Cluster, Task Definition, Service (using Fargate)**

This file sets up how your FastAPI app runs on AWS without managing servers. **ECS (Elastic Container Service)** is AWS's container orchestration platform — similar to Kubernetes, but AWS-managed. It takes care of running containers, scaling them, and keeping them healthy. **Fargate** is a serverless compute engine for containers. When you choose ECS with Fargate, you don’t have to launch or manage EC2 instances (VMs). You just define what your container needs (CPU, RAM), and AWS provisions and runs it behind the scenes. In short, ECS manages containers, Fargate runs them.

Here's what the ecs.tf does:
- ECS Cluster: A logical container for running tasks and services. It doesn’t cost anything by itself — just a grouping mechanism.
- Task Definition defines which Docker image to run (from ECR), how much CPU/RAM to allocate, runtime settings like ports, environment variables, IAM roles, etc. I also specify the Fargate launch type here — telling ECS to use Fargate to run this task (not EC2).
- Service keeps a specified number of task instances running. If a container crashes, the service spins up a replacement automatically.
It also connects tasks to the Application Load Balancer (ALB), so incoming traffic can be distributed across running tasks.

**5. `alb.tf` – Application Load Balancer Setup**

Handles traffic routing:
- ALB : Public entry point for your API
- Target Group : Routes traffic to ECS tasks
- HTTP Listener : Listens on port 80 and forwards traffic to target group
- Security Groups : Controls who can access the ALB and ECS tasks
  - Allows internet traffic to reach the ALB on port 80.
  - Restricts ECS tasks to only accept traffic from the ALB (not directly from the internet)
- How it all works
  - Client sends HTTP request to ALB’s public DNS name.
  - ALB routes traffic to healthy ECS tasks (via target group).
  - Target Group monitors ECS tasks via `/health` endpoint, ping every minute. Health checks ensure requests only go to healthy tasks.

**6. `variables.tf`**
- model bucket, path to not hardcode


```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform apply -auto-approve  # Applies all changes without asking for confirmation
```

**Output**
- alb_dns_name = "california-housing-api-360463802.us-east-1.elb.amazonaws.com"
- ecr_repository_url = "418272790285.dkr.ecr.us-east-1.amazonaws.com/california-housing-api"
- ecs_task_definition = "arn:aws:ecs:us-east-1:418272790285:task-definition/california-housing-api:3"
- ecs_task_role_arn = "arn:aws:iam::418272790285:role/california-housing-api-task-role"

--> http://california-housing-api-360463802.us-east-1.elb.amazonaws.com/health

You can check CloudWatch to see logs like below:

```
INFO: Waiting for application startup.
INFO:main:Starting up and loading MLflow model...
INFO:main:Loading model directly from S3: s3://s3-ttran-models/mlflow/models/california-housing/5
INFO:main:Model loaded successfully.
INFO:main:Sample prediction: 5.093137741088867
INFO: Application startup complete.
INFO: 10.0.2.159:8986 - "GET /health HTTP/1.1" 200 OK
INFO: 10.0.1.140:11060 - "GET /health HTTP/1.1" 200 OK
```

**ECS and ALB Health checks**

I applied layered health check design
- `GET /health` is lightweight — used by the ALB to check if the web server (FastAPI) is up.
- `GET /ready` is deep — used by ECS task to determine if the app is functionally ready (e.g., model loaded, DB connection live).

You will see many logs in CloudWatch about health check from both Docker and ALB. That because every 20 seconds, Docker and ALB runs health check (defined in FastAPI app `main.py`) to see if the app is healthy. If it takes 3 failures in a row (so at least 60 seocnds), the target will be marked unhealthy.

**Build and Push a Docker image to AWS ECR**

Add dependencies from MLFlow model to requirements.txt for Docker image, so the xgboost model can run in Docker container. Use `chmod +x` to make the script executable - we just need to run once.
```bash
chmod +x build_push_docker.sh 
./build_push_docker.sh
```

**New deployment**

- When you are in 2 situation below, you need to force deployment:
  - Upload a new model version to S3. If using `latest` folder and Keep MODEL_PATH=`mlflow/models/california-housing/latest`
  - Run build_push_docker.sh to push a new Docker image to ECR

```bash
aws ecs update-service --cluster california-housing-api --service california-housing-api --force-new-deployment
terraform output alb_dns_name
```

- Rollback to a previous version: run this command to update the variable "model_path".

```bash
terraform apply -var "model_path=mlflow/models/california-housing/6"
```

What happens after running `terraform apply -var`
- Terraform updates ECS task definition, ECS service will deploy new tasks with updated environment variables.
- FastAPI app `main.py` reads the new `MODEL_PATH` from evn, load new model version from S3
- No Docker image rebuild or code changes needed

### Clean Up AWS

**Free tier**
- VPC, subnets, route tables
- ECR: limited 500 Mb/month
- IAM Roles / Policies
- CloudWatch: limited
- S3: limited 5 GB / month

**Cost**
- ECS + Fargate
- ALB

Delete the ECS service (which stops tasks too). Optional to delete the cluster

```bash
aws ecs delete-service \
  --cluster california-housing-api \
  --service california-housing-api \
  --force

aws ecs delete-cluster \
  --cluster california-housing-api
```

Delete the ALB: Go to EC2 > Load Balancers > Select and delete. It will delete ALB and associated resources (target groups, listener, security groups)


```bash
cd terraform
terraform destroy
```

### Reality

Leave there for 30 minutes. Check CloudWatch, found many security scans sent to my application by automated tools trying to find vulnerabilities. As below, you can see that those tools were looking for exposed assets, they can also scan for common AWS misconfigurations.

```
INFO: 10.0.2.159:32278 - "GET /nice%20ports%2C/Trinity.txt.bak HTTP/1.1" 404 Not Found
INFO: 10.0.2.159:44474 - "GET /hazelcast/rest/cluster HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /.git/HEAD HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /server/.env HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /server/config.php HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /server/info.php HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /server/settings.json HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /.aws/credentials HTTP/1.1" 404 Not Found
INFO: 10.0.1.140:37784 - "GET /docker-compose.yml HTTP/1.1" 404 Not Found
```
Security best practices that can apply:
Place ECS tasks and ALB in private subnets (not publicly routable) to reduce exposure to external threats. as we want to make the API externally accessible, we must assign the ALB a public IP while The ECS tasks must remain completely private. Since private subnets don’t have direct internet access to pull models from S3 or download packages, we need to configure a NAT Gateway in a public subnet.
Restrict ALB Inbound and Outbound Traffic.
Deploy AWS Web Application Firewall (WAF) in front of the ALB to filter by IP range or country.
