output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "ecs_task_definition" {
  description = "ECS Task Definition ARN"
  value       = aws_ecs_task_definition.fastapi_task.arn
}

# Output the Role ARN
output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}