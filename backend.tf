# POC state is stored locally in terraform.tfstate.
# For production, switch to a remote S3 backend with DynamoDB locking so the
# state is shared across the team and encrypted at rest.
#
# terraform {
#   backend "s3" {
#     bucket         = "mcloud-terraform-state-prod"
#     key            = "network/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "mcloud-terraform-locks"
#     encrypt        = true
#   }
# }
