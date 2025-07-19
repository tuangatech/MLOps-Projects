# modules/mwaa/outputs.tf

output "mwaa_environment_name" {
  description = "Name of the MWAA environment"
  value       = aws_mwaa_environment.main.name
}

output "mwaa_environment_arn" {
  description = "ARN of the MWAA environment"
  value       = aws_mwaa_environment.main.arn
}

output "mwaa_airflow_webserver_url" {
  description = "URL of the Airflow Webserver"
  value       = aws_mwaa_environment.main.webserver_url
}

output "mwaa_dag_s3_path" {
  description = "S3 path where DAGs are stored"
  value       = var.dag_s3_path
}

output "mwaa_execution_role_arn" {
  description = "IAM Role used by MWAA"
  value       = var.airflow_role_arn
}