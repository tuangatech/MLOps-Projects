# End-to-End ML Deployment with MLflow, FastAPI, and AWS Fargate
In this project, I walk through how to train, track, and deploy a machine learning model using a modern MLOps stack — combining XGBoost, MLflow, FastAPI, and AWS ECS with Fargate. The goal is to build a regression model that predicts the median house value of a California block group based on features like income level, house age, number of rooms, and geographic location. I use XGBoost for its strong performance on tabular data and MLflow to track training runs, log metrics, and register the trained model for deployment. 

Once the model is trained and registered in MLflow, I use FastAPI to create a simple web service that exposes a`/predict` endpoint for real-time inference. To deploy this service in a scalable and serverless way, I containerize the application with Docker and run it on AWS ECS with Fargate, which handles infrastructure management without needing to provision EC2 instances. 

This end-to-end solution demonstrates a practical approach to deploying ML models in production with a clean, reproducible workflow. It’s particularly useful for developers and data scientists who want a minimal yet scalable setup without diving deep into Kubernetes or setting up custom inference servers.

### High-Level Approach
In this project, we aim for a clean and scalable deployment of a machine learning model using tools and best practices below.

1. The trained model will be downloaded from S3 bucket **at runtime** instead of baking it into the Docker image. Hence, updating the model becomes much simpler — I don’t have to rebuild or redeploy the Docker image every time there's a change. It also allows me to rollback easily, which is a big deal for production reliability. Since the XGBoost model is small (only around 7MB), the cold start impact from downloading it dynamically is small.

2. I use **MLFlow** to keep track of the experiments and manage different model versions without relying on manual notes. It logs all the important details like training parameters, evaluation metrics, and generated artifacts (e.g., plots or confusion matrices). Additionally, MLFlow's model registry helps us manage model versions properly, and I know which one to roll forward or backward when needed.

3. **FastAPI** is a better choice than Flask for serving ML models as it has built-in async support, which can handle multiple inference requests concurrently without blocking. That’s a big win if you're deploying in a production environment with real-time traffic. It also offers automatic input validation with Pydantic and auto-generates interactive API docs (Swagger). 

4. I use **AWS ECS with Fargate** to deploy the FastAPI app. This setup lets me run containers in a serverless way — meaning we don’t have to manually provision or manage EC2 instances (VMs). Fargate only charges for the compute we actually use, which keeps costs down, and it supports features like auto-scaling (even though we’re not using that part yet). The containers run inside a VPC and can assume IAM roles, so security and networking are good. 

5. I use **Terraform** to setup AWS infrastructure which treats infrastructure as code (IaC). We can describe everything — VPCs, load balancers, ECS tasks, etc. — in configuration files, which can be committed to version control and reused across environments. It also makes deployments reproducible and easier to automate through CI/CD pipelines.


### Local Development
The main purpose of this project is not about developing the best performance model - the goal is to build an end-to-end MLOps pipeline that goes from training to deployment. In this section, I use the California Housing dataset as a lightweight example to demonstrate the pipeline steps: Train → Evaluate → Log → Register → Store.

1. Model Training with XGBoost
- Load the California housing dataset from `sklearn.datasets` and drop obvious outliers to clean the data.
- Tune XGBRegressor hyperparameters using `RandomSearchCV` with 20 random combinations and 5-fold cross-validation for better generalization.
- Finds the best hyperparameters that minimize prediction error
- Evaluate the model on test data and calculates RMSE and MAE (accuracy metrics)

```python
model = xgb.XGBRegressor(random_state=42, objective='reg:squarederror')

param_dist = {
    'n_estimators': [200, 300, 500],
    'max_depth': [6, 8, 10, 12],
    'learning_rate': [0.01, 0.05, 0.1, 0.2],
    'subsample': [0.4, 0.6, 0.8, 1.0]
}

search = RandomizedSearchCV(
    estimator=model,
    param_distributions=param_dist,
    n_iter=20, cv=5,            
    scoring='neg_mean_squared_error',                      
    n_jobs=-1, verbose=1, random_state=42)
```

2. Experiment Tracking with MLflow
- MLflow is used to track all experiment artifacts: hyperparameters, metrics, trained model, and visualizations.
- I log everything with MLflow: best parameters, the model artifacts, evaluation metrics (MAE, RMSE),  feature importance plot, true vs predicted values plot
- Register the best model in MLflow with the name "california-housing" for version control.
- Once registered, the model and its artifacts are exported and uploaded to Amazon S3, ready for serving.
- You can explore the experiment history using the MLflow UI by running `mlflow ui` on a Bash terminal and open http://localhost:5000/. From the UI, a developer can compare different runs and their parameters/metrics side by side and check training diagnostics and plots logged during training.

  ```python
  mlflow.set_experiment(EXPERIMENT_NAME)
  input_example = X_train.head(5)

  with mlflow.start_run() as run:
      search.fit(X_train, y_train)
      
      best_params = search.best_params_
      best_model = search.best_estimator_

      # Predict and evaluate
      y_pred = best_model.predict(X_test)
      rmse = np.sqrt(mean_squared_error(y_test, y_pred))
      mae = mean_absolute_error(y_test, y_pred)

      # Log metrics and model
      mlflow.log_params(best_params)
      mlflow.log_metrics({"rmse": rmse, "mae": mae})
      mlflow.xgboost.log_model(best_model, "model", input_example=input_example)

      # Feature Importance Plot
      fig1, ax1 = plt.subplots(figsize=(6, 5))
      xgb.plot_importance(best_model, ax=ax1)
      ax1.set_title("Feature Importance")
      mlflow.log_figure(fig1, "plots/feature_importance.png")
  ```

3. Serving with FastAPI
- A lightweight FastAPI app wraps the trained model into a RESTful inference service.
- On startup, the app reads S3 bucket and path from environment variables (injected by ECS task definitions).
- Loads the MLflow model directly from S3 using `mlflow.pyfunc.load_model()`.
- The API exposes three endpoints:
  - `GET /health`: Simple liveness check to confirm the app is running
  - `GET /ready`: Verifies that the model is successfully loaded and ready to serve predictions
  - `POST /predict`: Accepts housing feature input as JSON, runs inference, and returns predicted median house value using loaded model.

  ```python
  app = FastAPI(
      title="California Housing Price Predictor",
      description="Predict housing prices",
      version="1.0"
  )
  @app.on_event("startup")
  def load_model():
      global model
      logger.info("Starting up and loading MLflow model...")

      try:        
          model_uri = f"s3://{MODEL_BUCKET_NAME}/{MODEL_PATH}"
          model = mlflow.pyfunc.load_model(model_uri)
      except Exception as e:
          logger.error(f"Failed to load model: {e}")
          raise
  ```

### Model Packaging
**1. Dockerize the FastAPI app**
- Start with the official `python:3.11-slim` image — it’s lightweight and sufficient for this solution.
- Copy `requirements.txt` first so Docker can cache the install layer. If the dependencies don’t change, we skip reinstalling them every time.
- Use `--no-cache-dir` in production Dockerfiles to have smaller images containing only installed packages, no temp files.
- Copy the FastAPI source code (e.g., `main.py`) into the app folder in the container.
- Tell Docker to check if the app is ready by hitting `/ready` endpoint every 30 seconds.
- Run the FastAPI app using Uvicorn.

```docker
COPY docker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ /app/

# Expose port for FastAPI
EXPOSE 80

# Health check (recommended for ECS)
HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:80/ready || exit 1

# Start the server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
```

**2. Local Testing: Validate Before You Deploy**

Before pushing your FastAPI app in a Docker container or to production, always test it locally. This simple step can save you hours of debugging later.

Local testing helps me catch many issues early, such as:
- Missing or incompatible dependencies
- Incorrect file paths when copying files into the Docker image
- MLFlow model loading failures (e.g., S3 access, path issues)
- Permission issues with temp folders or local storage
- Misconfigured API endpoints or logic bugs in endpoints
- Input parsing logic with Pydantic in `predict` endpoint

Running everything outside of Docker first gives you a quick sanity check.

a. Run FastAPI app natively (wthout Docker)

Start by launching the FastAPI app directly using Uvicorn.

```bash
# Navigate to the app directory and run the server
cd app
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Once the server is running
- Open http://localhost:8000/ready - this endpoint should return `{"status": "ready"}` if the model loads correctly.
- Open http://localhost:8000/docs - you can try out `/predict` endpoint via Swagger UI, just need to update input value and click Execute to get the prediction.

This step confirms your environment is correctly set up and the model loads from S3 as expected.

b. Build & Run Docker image locally

Once the native run looks good, test the same app inside a Docker container — this mimics how it will run on AWS. We build the image and run the container to map port 80 inside the container to port 8000 on our local machine.

```bash
cd docker
docker build -t my-fastapi-app .  
docker run -p 8000:80 my-fastapi-app
```

Once again, we can open browser and check the responses. If this works, it means the application logic and the container environment are validated. Now, the image is ready to push to Amazon ECR and deploy to ECS + Fargate.

**3. Build and Push Docker image to ECR**

To streamline the process, I created a script `build_push_docker.sh`:
- Build the Docker image and tag with ECR repository URI
- Authenticate with Amazon ECR using the AWS CLI and push that Docker image to ECR repo.

Make sure the ECR repository already exists before running the script. This is typically handled through infrastructure provisioning (e.g., Terraform), which we’ll cover in the next section.


### AWS Infrastructure Setup (Terraform-based)

This solution adopts several AWS services to ensure secure and scalable production environment for the FastAPI app. The infrastructure is defined as code (IaC) using the following Terraform modules.

**1. `vpc.tf` – Virtual Private Cloud & Subnet Setup**

This file defines the core networking for the app. Even my FastAPI app is public-facing, AWS requires the ECS tasks to run inside a VPC for security and network control. This setup includes:
- A custom VPC
- Two public subnets, each in a different Availability Zones for high availability. 
- An Internet Gateway to provide internet access
- A public route table and subnet associations

Load Balancers (ALBs) require at least two subnets in different AZs to operate correctly in production.

**2. `alb.tf` – Application Load Balancer Setup**

Sets up public access to my FastAPI API:
- ALB: Public entry point for your API
- Target Group: Routes traffic to ECS tasks
- HTTP Listener: Listens on port 80 and forwards traffic to target group
- Security Groups : Controls who can access the ALB and ECS tasks
  - Allows internet traffic to reach the ALB on port 80.
  - Restricts ECS tasks to only accept traffic from the ALB (not directly from the internet)
- How it all works?
  - Client sends HTTP request to ALB’s public DNS name.
  - ALB routes traffic to healthy ECS tasks (via target group).
  - Target Group monitors ECS tasks via `/health` endpoint, ping every 30 seconds. Health checks ensure requests only go to healthy tasks.


**3. `iam.tf` – IAM Roles for ECS**

This file defines the Identity and Access Management (IAM) roles required by the ECS workloads:
- Execution role for **ECS** `ecs_task_execution_role` to pull images and write logs to CloudWatch.
- Task role for the **FastAPI app** to access AWS services like S3 or CloudWatch, limit to a specific bucket and log group only.
- Exposes the Task Role ARN `output "ecs_task_role_arn"` so it can be reused in `ecs.tf` when defining the ECS Task definition.

**4. `ecs.tf` – ECS Cluster, Task Definition, Service (using Fargate)**

This file sets up how the FastAPI app runs on AWS without managing servers. **ECS (Elastic Container Service)** is AWS's container orchestration platform — similar to Kubernetes, but AWS-managed. It takes care of running containers, scaling them, and keeping them healthy. **Fargate** is a serverless compute engine for containers. When you choose ECS with Fargate, you don’t have to launch or manage EC2 instances (VMs). You just define what your container needs (CPU, RAM), and AWS provisions and runs it behind the scenes. In short, ECS manages containers, Fargate runs them.

Here's what the `ecs.tf` defines:
- ECS Cluster: A logical container for running tasks and services. It doesn’t cost anything by itself — just a grouping mechanism.
- Task Definition defines which Docker image to run (from ECR), how much CPU/RAM to allocate, runtime settings like ports, environment variables, IAM roles, etc. I also specify the Fargate launch type here — telling ECS to use Fargate to run this task (not EC2).
- Service keeps a specified number of task instances running. If a container crashes, the service spins up a replacement automatically.
It also connects tasks to the Application Load Balancer (ALB), so incoming traffic can be distributed across running tasks.
- Keep logs in CloudWatch for 7 days only.

**5. `ecr.tf` – Docker Registry**

This file creates an Amazon ECR repository where you'll push your FastAPI Docker image to, for ECS to pull and run. You can think of ECR as a private Docker Hub, fully managed by AWS and integrated with IAM and ECS.

**6. `variables.tf`**
- Centralizes project config like: project name, region, model bucket, model path.
- Avoids hardcoding; use variables across Terraform files for portability and reuse.


**Why This Infrastructure Matters**
- Security: VPC isolates resources; IAM roles grant only the permissions the app needs (least-privilege).
- Scalability: Fargate auto-scales containers; ALB distributes traffic and keeps requests flowing to healthy services.
- Cost-Efficiency: With Fargate, we pay only when containers are running, not for idle EC2 instances.


### Deploying AWS Infrastructure with Terraform

Once all terraform configs are ready, navigate to the terraform folder and run the standard workflow:
```bash
cd terraform
terraform init    # Initialize Terraform (downloads providers, sets up backend)
terraform plan    # Preview changes before applying
terraform apply   # Apply changes with confirmation
terraform apply -auto-approve  # Applies all changes without asking for confirmation
```

**1. Terraform Output**

```
alb_dns_name        = "california-housing-api-360463802.us-east-1.elb.amazonaws.com"
ecr_repository_url  = "418272790282.dkr.ecr.us-east-1.amazonaws.com/california-housing-api"
ecs_task_definition = "arn:aws:ecs:us-east-1:418272790282:task-definition/california-housing-api:3"
ecs_task_role_arn   = "arn:aws:iam::418272790282:role/california-housing-api-task-role"
```

With `alb_dns_name` above, you can check the deployed API at: http://california-housing-api-360463802.us-east-1.elb.amazonaws.com/health

**2. Build and Push Docker image to AWS ECR**

Now, when the AWS infrastructure is ready, we build and push the Docker image. If you are using Mac or Wins, you need to turn on Docker Desktop to provide a Linux VM to run commands like `docker build`, `docker push`.
- Make sure MLFlow model dependencies (e.g., xgboost, scikit-learn) are in `requirements.txt`, so the xgboost model can run in Docker container.
- Use `chmod +x` to make the script executable - we just need to run once.

```bash
chmod +x build_push_docker.sh 
./build_push_docker.sh
```

**3. CloudWatch Logs**
You can check CloudWatch to confirm startup and health check behavior. There are 2 healthcheck records at the same time because we have 2 AZs and each AZ has its own load balancer node, and each node independently check the target's health:

```
INFO: Waiting for application startup.
INFO:main:Starting up and loading MLflow model...
INFO:main:Loading model directly from S3: s3://ttran-models/mlflow/models/california-housing/latest
INFO:main:Model loaded successfully.
INFO:main:Sample prediction: 5.093
INFO: Application startup complete.
INFO: 10.0.1.57:59708 - "GET /health HTTP/1.1" 200 OK
INFO: 10.0.2.233:4900 - "GET /health HTTP/1.1" 200 OK
```

**4. Health Check Design**

I applied 2-layer health checks:
- `GET /health` is lightweight — used by the ALB to check if a particular ECS task is healthy enough to receive new traffic from the load balancer. If a task fails the ALB health check, the ALB stops routing traffic to that specific task instance. It will redirect traffic to other healthy instances.
- `GET /ready` is deep — used by ECS task to determine if the app inside the container is running correctly and is healthy from the container's own perspective (e.g., model loaded, DB connection live). If it fails repeatedly, ECS considers the task unhealthy, stops it, and launches a replacement to maintain service levels.

Health checks run every 20 seconds. If 3 consecutive failures occur (60 seconds), ECS marks the task as unhealthy and restarts it.


### New Deployment Guide

**1. Rollout new artifacts**

- You need to trigger a forced deployment in either of the following scenarios::
  - A new model version is uploaded to S3 (e.g., in the `latest` folder with `MODEL_PATH=mlflow/models/california-housing/latest`)
  - A new Docker image is built and pushed using `build_push_docker.sh`.

```bash
aws ecs update-service --cluster california-housing-api --service california-housing-api --force-new-deployment
terraform output alb_dns_name
```

**2. Rolling Back to a Previous Model Version**

- If the new model version causes issues, roll back by updating the model_path variable:

```bash
terraform apply -var "model_path=mlflow/models/california-housing/6"
```

What happens after running `terraform apply -var`
- Terraform updates ECS task definition with the new MODEL_PATH.
- ECS service replaces running tasks with new ones using the updated environment variable.
- FastAPI app `main.py` reads the new `MODEL_PATH` from evn and loads the corresponding model version from S3.
- No Docker image rebuild or code changes needed

### Clean Up AWS
When you are done with an experiment, it's important to shut down AWS resources that can incur ongoing charges. In this case, ECS + Fargate bills per second of compute time and ALB charged on usage. Amazon S3 is free up to 5 GB/month, so consider deleting unused buckets and objects.

**Clean-Up Steps**
- Delete the ECS service (which stops tasks too). Optional to delete the cluster

```bash
aws ecs delete-service \
  --cluster california-housing-api \
  --service california-housing-api \
  --force

aws ecs delete-cluster \
  --cluster california-housing-api
```

- Delete the ALB: Go to EC2 > Load Balancers > Select ALB and delete. It will delete ALB and listeners which tied directly to the ALB.

- When you are done with the project, you can destroy infrastructure from your terraform folder. This will remove infrastructure defined in Terraform: VPC, subnets, IAM roles, security groups and ECR repository.

```bash
cd terraform
terraform destroy
```

Now, you can ensure that the AWS environment is clean and you will receive no unexpected charges.

### What Happens Post Go-Live?
Once the model is deployed and publicly exposed—even for just 30 minutes—you’ll likely see traffic from automated vulnerability scanners crawling your app. This is exactly what happened after deploying to AWS. A quick check in CloudWatch logs revealed dozens of unsolicited requests to check known weaknesses.

Here's what I copied from my CloudWatch.
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
These are classic signs of bots and scanners searching for exposed assets, misconfigured files, and environment secrets—everything from .git folders to docker-compose.yml and AWS credentials.

**Secure Your Deployment**

To secure your application without sacrificing availability, follow these security best practices:
- The ALB must sit in a public subnet to expose APIs externally but the ECS tasks (running the model) should always stay in private subnets to prevent direct access. Since private subnets lack direct internet access, we can use a NAT Gateway (in a public subnet) so ECS tasks can still reach S3 or pull packages.
- Restrict ALB inbound and outbound traffic.
- Deploy AWS Web Application Firewall (WAF) in front of the ALB to filter by IP range or country.

If we put our application online, it will get scanned immediately. Don't assume your app is safe by default, secure your infra from day 1.