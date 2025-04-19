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
          "s3:ListBucket" # Add this action
        ],
        Resource = [
          aws_dynamodb_table.csv_table.arn,
          aws_sns_topic.csv_topic.arn,
          aws_secretsmanager_secret.sns_secret.arn,
          aws_lambda_function.csv_lambda.arn,
          "arn:aws:s3:::csv-upload-bucket-tdesai",  # Allow ListBucket at the bucket level
          "arn:aws:s3:::csv-upload-bucket-tdesai/*", # Allow GetObject for all objects in the bucket
          "arn:aws:logs:*:*:log-group:/aws/lambda/CsvFileHandlerLambda*"
        ]
      }
    ]
  })
}