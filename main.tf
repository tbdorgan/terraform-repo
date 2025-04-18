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

resource "aws_s3_bucket" "csv_bucket" {
  bucket = var.csv_bucket_name
  force_destroy = true
}

resource "aws_dynamodb_table" "csv_table" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "filename"

  attribute {
    name = "filename"
    type = "S"
  }
}

resource "aws_sns_topic" "csv_topic" {
  name = var.sns_topic_name
}

resource "aws_secretsmanager_secret" "sns_secret" {
  name = var.sns_secret_name
}

resource "aws_secretsmanager_secret_version" "sns_secret_version" {
  secret_id     = aws_secretsmanager_secret.sns_secret.id
  secret_string = var.sns_endpoint
}

resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = var.lambda_bucket_name
  force_destroy = true

  tags = {
    Name = "lambda-artifacts"
  }
}



resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-csv-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-csv-policy"
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
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "csv_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "com.example.CsvHandler::handleRequest"
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

  depends_on = [aws_iam_role_policy_attachment.lambda_policy_attach]
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

resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.csv_bucket.arn
}
