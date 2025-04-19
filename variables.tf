variable "aws_region" {
  description = "The AWS region where resources will be created"
  default     = "eu-west-2"
}

variable "csv_bucket_name" {
  description = "Name of the S3 bucket to store CSV files"
  default     = "csv-upload-bucket-tdesai"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to store CSV metadata"
  default     = "csv-files-table"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  default     = "csv-upload-topic"
}

variable "sns_secret_name" {
  description = "Name of the Secrets Manager secret for SNS endpoint"
  default     = "csv-sns-endpoint-secret"
}

variable "sns_endpoint_secret_name" {
  description = "The parameter or secret name for SNS endpoint email in Secrets Manager"
  default     = "/prod/sns/email"  # Use SSM or Secrets Manager for sensitive information
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  default     = "CsvFileHandlerLambda"
}

variable "lambda_bucket_name" {
  description = "S3 bucket to store Lambda deployment artifacts"
  default     = "my-lambda-deployments-bucket-123456"
}

variable "lambda_s3_key" {
  description = "The S3 key for the Lambda zip deployment package"
  default     = "lambda/csv-processor.zip"
}

