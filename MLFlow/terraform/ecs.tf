# Create an ECS cluster to host our FastAPI service
resource "aws_ecs_cluster" "main" {
  name = var.project_name
}

# Define how the FastAPI container should run
resource "aws_ecs_task_definition" "fastapi_task" {
  family                   = var.project_name
  network_mode             = "awsvpc"                # Use VPC networking
  requires_compatibilities = ["FARGATE"]             # Run on serverless Fargate
  cpu                      = "256"                   # CPU allocation
  memory                   = "512"                   # Memory allocation
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Container settings
  container_definitions = jsonencode([{
    name      = var.project_name
    image     = "${aws_ecr_repository.fastapi_repo.repository_url}:latest"  # Image from ECR
    portMappings = [{
      containerPort = 80   # App listens on port 80
      hostPort    = 80
      protocol    = "tcp"
    }]
    environment = [
      {
        name  = "MODEL_BUCKET_NAME"
        value = var.model_bucket_name    # S3 bucket where MLflow model is stored
      },
      {
        name  = "MODEL_PATH"
        value = var.model_path  # Path to model in S3, get by os.getenv("MODEL_PATH")
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"                    # Send logs to CloudWatch
      options = {
        awslogs-group         = "/ecs/${var.project_name}"
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# Deploy the FastAPI service and keep it running
resource "aws_ecs_service" "fastapi_service" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fastapi_task.arn
  desired_count   = 1              # Number of containers to run
  launch_type     = "FARGATE"      # Run on serverless infrastructure

  network_configuration {
    security_groups = [aws_security_group.ecs_sg.id]
    subnets         = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    assign_public_ip = true
  }

  # Connect to ALB
  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.project_name
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/${var.project_name}"
  retention_in_days = 7  # Optional: how long to keep logs
}