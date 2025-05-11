# Create an ECR repository to store FastAPI Docker images
resource "aws_ecr_repository" "fastapi_repo" {
  name                 = var.project_name               # Use project name as repo name
  image_tag_mutability = "MUTABLE"                    # Allow overwriting :latest tag

  # Optional: Scan images on push for vulnerabilities
  image_scanning_configuration {
    scan_on_push = true
  }

  # Tag the repo for easier filtering in AWS Console
  tags = {
    Environment = var.environment
  }
}

# Output the ECR repository URL (used in ECS deployment)
output "ecr_repository_url" {
  value = aws_ecr_repository.fastapi_repo.repository_url
}