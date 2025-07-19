output "s3_buckets" {
  value = module.s3
}

output "iam_roles" {
  value = module.iam
}

output "lambda_functions" {
  value = module.lambda
}

output "dynamodb_table_arn" {
  value = module.dynamodb.prediction_logs_arn
}

output "eventbridge_rule_name" {
  value = module.eventbridge.rule_name
}