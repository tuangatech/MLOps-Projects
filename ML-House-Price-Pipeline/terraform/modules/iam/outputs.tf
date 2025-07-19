output "sagemaker_execution_role_arn" {
  value = aws_iam_role.sagemaker_execution_role.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  value = aws_iam_role.lambda_role.name
}

output "mwaa_role_arn" {
  value = aws_iam_role.mwaa_role.arn
}