# End-to-End ML Deployment with MLflow, FastAPI, and AWS Fargate
In this project, I walk through how to train, track, and deploy a machine learning model using a modern MLOps stack — combining XGBoost, MLflow, FastAPI, and AWS ECS with Fargate. The goal is to build a regression model that predicts the median house value of a California block group based on features like income level, house age, number of rooms, and geographic location. I use XGBoost for its strong performance on tabular data and MLflow to track training runs, log metrics, and register the trained model for deployment. 

Once the model is trained and registered in MLflow, I use FastAPI to create a simple web service that exposes a`/predict` endpoint for real-time inference. To deploy this service in a scalable and serverless way, I containerize the application with Docker and run it on AWS ECS Fargate, which handles infrastructure management without needing to provision EC2 instances. 

This end-to-end solution demonstrates a practical approach to deploying ML models in production with a clean, reproducible workflow. It’s particularly useful for developers and data scientists who want a minimal yet scalable setup without diving deep into Kubernetes or setting up custom inference servers.

### High-Level Approach
In this project, we aim for a clean and scalable deployment of a machine learning model using tools and best practices below.

1. The trained model will be downloaded from S3 bucket **at runtime** instead of baking it into the Docker image. Hence, updating the model becomes much simpler—you don’t have to rebuild or redeploy the Docker image every time there's a change. It also allows us to rollback easily, which is a big deal for production reliability. Since our XGBoost model is small (only around 7MB), the cold start impact from downloading it dynamically is negligible.

2. We use **MLFlow** to keep track of our experiments and manage different model versions without relying on manual notes. It logs all the important details like training parameters, evaluation metrics, and generated artifacts (e.g., plots or confusion matrices). Additionally, MLFlow's model registry helps us manage model versions properly, and we know which one to roll forward or backward when needed.

3. **FastAPI** is a better choice than Flask for serving ML models as it has built-in async support, which can handle multiple inference requests concurrently without blocking. That’s a big win if you're deploying in a production environment with real-time traffic. It also offers automatic input validation with Pydantic and auto-generates interactive API docs (Swagger). 

4. I use **AWS ECS with Fargate** to deploy the FastAPI app. This setup lets me run containers in a serverless way — meaning we don’t have to manually provision or manage EC2 instances. Fargate only charges for the compute we actually use, which keeps costs down, and it supports features like auto-scaling (even though we’re not using that part yet). Our containers run inside a VPC and can assume IAM roles, so security and networking are well-contained.

5. I use **Terraform** to setup AWS infrastructure which treats infrastructure as code. We can describe everything — VPCs, load balancers, ECS tasks, etc. — in configuration files, which can be committed to version control and reused across environments. It also makes deployments reproducible and easier to automate through CI/CD pipelines.

**Why This Matters**
- Security: VPC + IAM enforce least-privilege access.
- Scalability: Fargate + ALB handle traffic spikes.
- Cost-Efficiency: Pay only for running containers (Fargate).

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

Actually, we need to have ECR repo created first (by terraforms in the next section), then we can push Docker image to ECR.


### AWS Infrastructure Setup

1. `vpc.tf` – Virtual Private Cloud Setup
This file sets up a secure networking environment where your FastAPI app will run. Even if your app is public-facing (via ALB), it should run inside a VPC for security, scalability, and compliance. It includes
- A VPC
- Two public subnets (in different availability zones): two public subnets in two different Availability Zones (AZs) for high availability (HA) and fault tolerance. If us-east-1a fails, traffic automatically routes to us-east-1b (via a load balancer or redundant deployments). AWS guarantees AZs are physically isolated, so disasters (power outages, floods) won’t take down both. An ALB/NLB requires at least two subnets in different AZs to distribute traffic. Dev/test environments can use single subnet. For production, always use >= 2 AZs.
- An Internet Gateway
- Public route table: A public route table is a set of rules (routes) that determine how traffic is directed from subnets to external networks (like the internet)
- Subnet associations

2. `ecr.tf` – Elastic Container Registry
This file creates an Amazon ECR repository where you'll push your FastAPI Docker image. You can think of ECR as a private Docker Hub, fully managed by AWS and integrated with IAM and ECS.

3. `iam.tf` – IAM Roles & Policies
This file creates the IAM roles and policies needed to securely run your FastAPI app in ECS/Fargate. It includes:
- An **execution role** (used by ECS to manage container lifecycle)
- A **task role** (grants permissions to access S3 and CloudWatch)

4. `ecs.tf` – ECS Cluster, Task Definition, and Service
This file sets up the container orchestration layer — where your FastAPI app runs. It includes:
- ECS Cluster : Logical grouping of services/tasks
- Task Definition : What container image to run and how much CPU/memory to allocate
- Service : Keeps a desired number of tasks running and connects them to ALB

5. `alb.tf` – Application Load Balancer Setup
- ALB : Public-facing entry point for your API
- Target Group : Routes traffic to ECS tasks
- HTTP Listener : Listens on port 80 and forwards to target group
- Security Groups : Controls who can access the ALB and ECS tasks, 
  - Allows internet traffic to reach the ALB on port 80.
  - Restricts ECS tasks to only accept traffic from the ALB (not directly from the internet)
- How It All Works
  - Client → Sends HTTP request to ALB’s public DNS name.
  - ALB → Routes traffic to healthy ECS tasks (via target group).
  - Target Group → Monitors ECS tasks via /health endpoint.
  - Security Groups:
    - ALB: Allows HTTP/80 from the internet.
    - ECS: Only allows traffic from ALB (locked down).


```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Output**
- alb_dns_name = "california-housing-api-1736015763.us-east-1.elb.amazonaws.com"
- ecr_repository_url = "418272790285.dkr.ecr.us-east-1.amazonaws.com/california-housing-api"
- ecs_task_definition = "arn:aws:ecs:us-east-1:418272790285:task-definition/california-housing-api:2"
- ecs_task_role_arn = "arn:aws:iam::418272790285:role/california-housing-api-task-role"

--> http://california-housing-api-1736015763.us-east-1.elb.amazonaws.com/health

You can check CloudWatch to see logs like:

```
INFO: Waiting for application startup.
INFO:main:Starting up and loading MLflow model...
INFO:main:Loading model directly from s3://s3-ttran-models/mlflow/models/california-housing/5
INFO:main:Model loaded successfully.
INFO: Application startup complete.
INFO:main:Running readiness check...
INFO:main:Sample prediction: 5.093137741088867
```

ALB health check and Docker check internally.

You will see many logs for readiness check, that because every 30 seconds, Docker runs this command inside the container periodically to see if your app is healthy.

```bash
HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1
```

**Free tier**
- VPC, subnets, route tables
- ECR: limited 500 Mb/month
- IAM Roles / Policies
- CloudWatch: limited
- S3: limited 5 GB / month

**Cost**
- ECS + Fargate
- ALB


**Build and Push a Docker image to AWS ECR**

Add dependencies from MLFlow model to requirements.txt for Docker image, so the xgboost model can run in Docker container.
Use chmod +x build_push_docker.sh to make the script executable, run once, gives execute permission to the owner of the file
```bash
chmod +x build_push_docker.sh 
./build_push_docker.sh
```

### Clean Up AWS


```bash
# Delete the ECS service (which stops tasks too)
aws ecs delete-service \
  --cluster california-housing-api \
  --service california-housing-api \
  --force

# Delete the cluster
aws ecs delete-cluster \
  --cluster california-housing-api
```

Delete the ALB: Go to EC2 > Load Balancers > Select and delete. It will delete ALB and associated resources (target groups, listener, security groups)


```bash
cd terraform
terraform destroy
```
