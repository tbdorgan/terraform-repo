variable "aws_region" {
  default = "eu-west-2"
}

variable "csv_bucket_name" {
  default = "csv-upload-bucket-tdesai"
}

variable "dynamodb_table_name" {
  default = "csv-files-table"
}

variable "sns_topic_name" {
  default = "csv-upload-topic"
}

variable "sns_secret_name" {
  default = "csv-sns-endpoint-secret"
}

variable "sns_endpoint" {
  default = "exampletoshack.desai@egmail.com"
}

variable "lambda_function_name" {
  default = "CsvFileHandlerLambda"
}

variable "lambda_bucket_name" {
  default = "my-lambda-deployments-bucket-123456"
}

variable "lambda_s3_key" {
  default = "lambda/csv-processor.zip"
}


