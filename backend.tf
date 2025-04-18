terraform {
  backend "s3" {
    bucket         = "tdesai-terraform-state-bucket"  # Name of your S3 bucket
    key            = "state/terraform.tfstate"        # Path where the state file will be stored within the bucket
    region         = "eu-west-2"                      # AWS region where the bucket is located
    encrypt        = true                             # Enable encryption for the state file
    dynamodb_table = "terraform-locks"                # DynamoDB table for state locking (ensure this table exists)
    acl            = "bucket-owner-full-control"     # Set ACL for the state file (optional)
  }
}
