output "prediction_logs_table" {
  value = aws_dynamodb_table.prediction_logs.name
}

output "prediction_logs_arn" {
  value = aws_dynamodb_table.prediction_logs.arn
}