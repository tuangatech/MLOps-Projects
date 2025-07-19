resource "aws_mwaa_environment" "main" {
  name               = "${var.project_name}-${var.environment}"
  airflow_version    = "2.10.1"
  dag_s3_path        = var.dag_s3_path          # place to full DAGs from
  execution_role_arn = var.airflow_role_arn

  network_configuration {
    security_group_ids = [var.security_group_id]
    subnet_ids         = var.subnet_ids
  }

  source_bucket_arn = var.source_bucket_arn
}