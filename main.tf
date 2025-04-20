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

data "aws_caller_identity" "current" {}

# S3 Bucket for CSV file uploads
resource "aws_s3_bucket" "csv_bucket" {
  bucket         = var.csv_bucket_name
  force_destroy  = true
}

# DynamoDB Table for CSV metadata
resource "aws_dynamodb_table" "csv_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "employeeId"
  range_key    = "createdAt"

  attribute {
    name = "employeeId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}

# SNS Topic for notifications
resource "aws_sns_topic" "csv_topic" {
  name = var.sns_topic_name
}

# Secrets Manager - SNS Subscription Email
resource "aws_secretsmanager_secret" "sns_secret" {
  name = var.sns_secret_name
}

resource "aws_secretsmanager_secret_version" "sns_secret_version" {
  secret_id     = aws_secretsmanager_secret.sns_secret.id
  secret_string = jsonencode({
    email = "toshack.desai@egmail.com"
  })
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-csv-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda
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
          "lambda:UpdateFunctionCode",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_dynamodb_table.csv_table.arn,
          aws_sns_topic.csv_topic.arn,
          aws_secretsmanager_secret.sns_secret.arn,
          "arn:aws:s3:::${var.csv_bucket_name}/*",
          "arn:aws:logs:*:*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function - CSV Upload Handler (S3 Trigger)
resource "aws_lambda_function" "csv_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "com.example.CsvFileHandlerLambda::handleRequest"
  runtime       = "java21"
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

# S3 Trigger for csv_lambda
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.csv_bucket.arn
}

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

# SECOND LAMBDA FUNCTION (SNS Subscriber)
resource "aws_lambda_function" "sns_subscriber_lambda" {
  function_name = var.lambda_subscriber_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "com.example.sns.SendEmailFromDynamoDBLambda::handleRequest"
  runtime       = "java21"
  timeout       = 30
  memory_size   = 512

  s3_bucket = var.lambda_bucket_name
  s3_key    = var.lambda_subscriber_s3_key

  environment {
    variables = {
      # Add vars if needed
    }
  }
}

# SNS Permission to invoke sns_subscriber_lambda
resource "aws_lambda_permission" "allow_sns_invocation" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_subscriber_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.csv_topic.arn
}

# SNS Subscription (subscriber Lambda)
resource "aws_sns_topic_subscription" "lambda_subscriber" {
  topic_arn = aws_sns_topic.csv_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_subscriber_lambda.arn
}
