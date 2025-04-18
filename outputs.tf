output "lambda_function_name" {
  value = aws_lambda_function.csv_lambda.function_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.csv_bucket.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.csv_topic.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.csv_table.name
}
