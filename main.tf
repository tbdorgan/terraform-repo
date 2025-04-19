terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for CSV file uploads
resource "aws_s3_bucket" "csv_bucket" {
  bucket = var.csv_bucket_name
  force_destroy = true
}

# DynamoDB table to store CSV file metadata
resource "aws_dynamodb_table" "csv_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "filename"

  attribute {
    name = "filename"
    type = "S"
  }
}

# SNS Topic for CSV upload notifications
resource "aws_sns_topic" "csv_topic" {
  name = var.sns_topic_name
}

# Secrets Manager secret for SNS endpoint (Sensitive data)
resource "aws_secretsmanager_secret" "sns_secret" {
  name = var.sns_secret_name
}

# Version of the SNS Secret with the actual endpoint (Sensitive data)
resource "aws_secretsmanager_secret_version" "sns_secret_version" {
  secret_id     = aws_secretsmanager_secret.sns_secret.id
  secret_string = jsonencode({
    email = "toshack.desai@egmail.com"  # Sensitive data, fetched from Secrets Manager
  })
}

# IAM Role for Lambda function execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-csv-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "csv_lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.csv_lambda.function_name}"
  retention_in_days = 30  # Optional, adjust retention as needed
}

# Fetch current AWS account identity
data "aws_caller_identity" "current" {}


# IAM Policy for Lambda with specific permissions (Least Privilege)
resource "aws_iam_policy" "lambda_policy" {
  name   = "lambda-csv-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "sns:Publish",
          "secretsmanager:GetSecretValue",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode"
        ],
        Resource = [
          aws_dynamodb_table.csv_table.arn,
          aws_sns_topic.csv_topic.arn,
          aws_secretsmanager_secret.sns_secret.arn,
          aws_lambda_function.csv_lambda.arn,
          #aws_cloudwatch_log_group.csv_lambda_log_group.arn
          "arn:aws:logs:*:*:log-group:/aws/lambda/CsvFileHandlerLambda*"
          #"arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.csv_lambda.function_name}:*"
        ]
      }
    ]
  })
}

# Attach the IAM policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function to handle CSV uploads
resource "aws_lambda_function" "csv_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "com.example.CsvFileHandlerLambda::handleRequest"
  runtime       = "java17"
  timeout       = 30
  memory_size   = 512

  s3_bucket     = var.lambda_bucket_name
  s3_key        = var.lambda_s3_key

  environment {
    variables = {
      SNS_SECRET_NAME = aws_secretsmanager_secret.sns_secret.name
      SNS_TOPIC_ARN   = aws_sns_topic.csv_topic.arn
      DDB_TABLE_NAME  = aws_dynamodb_table.csv_table.name
    }
  }
}

# S3 Event Notification to trigger Lambda for .csv uploads
resource "aws_s3_bucket_notification" "csv_upload_trigger" {
  bucket = aws_s3_bucket.csv_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3_invocation]
}

# Allow S3 to invoke Lambda function
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.csv_bucket.arn
}

