# Create an Application Load Balancer
resource "aws_lb" "main" {
  name               = var.project_name
  internal           = false                     # Publicly accessible
  load_balancer_type = "application"             # ALB (vs NLB or GWLB)
  security_groups    = [aws_security_group.alb_sg.id]   # Controls inbound/outbound traffic, defined below
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Environment = var.environment
  }
}

# Define which ECS tasks receive traffic
# Health checks ensure requests only go to healthy tasks.
resource "aws_lb_target_group" "main" {
  name     = var.project_name
  port     = 80
  protocol = "HTTP"
  target_type = "ip"                    # target type for Fargate where the target is the private IP of the task
  vpc_id   = aws_vpc.main.id            # Ensures ALB can reach ECS tasks in the same VPC

  # Health check endpoint (should return HTTP 200)
  health_check {
    path                = "/health"      # Endpoint for health checks
    healthy_threshold   = 3             # 3 successful checks = healthy
    unhealthy_threshold = 3             # 3 failed checks = unhealthy
    timeout             = 5             # Timeout per check (seconds)
    interval            = 20            # Seconds between checks
    matcher             = "200"         # HTTP 200 = healthy
  }
}

# Listen on port 80 and forward to ECS tasks
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.cert.arn
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main.arn
#   }
# }

# Security group for ALB - allow HTTP from internet
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP traffic from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for ECS tasks - Restricts ECS tasks to only accept traffic from the ALB (not directly from the internet)
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow ALB to reach ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Only allow ALB to connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}