provider "aws" {
  region = "us-east-1"
}

# Create the IAM Role
resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker-intent-detection-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Amazon ECR Full Access Policy
resource "aws_iam_role_policy_attachment" "ecr_full_access" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Attach CloudWatch Logs Full Access Policy
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_full_access" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

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
  image_tag_mutability = "MUTABLE"  # Allow image tag updates (use "IMMUTABLE" for prod)
  image_scanning_configuration {
    scan_on_push = true # Automatically scans images for vulnerabilities
  }
}

# Output the ECR repository URL (used in SageMaker deployment)
output "ecr_repository_url" {
  value = aws_ecr_repository.intent_detection_model_repo.repository_url
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "sagemaker_secrets" {
  name = "sagemaker-deployment-secrets"
}

resource "aws_secretsmanager_secret_version" "secrets" {
  secret_id     = aws_secretsmanager_secret.sagemaker_secrets.id
  secret_string = jsonencode({
    SAGEMAKER_ROLE_ARN = aws_iam_role.sagemaker_role.arn
    ECR_IMAGE_URI      = "${aws_ecr_repository.intent_detection_model_repo.repository_url}:latest"
  })
}

