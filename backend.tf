terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The bucket must exist before `terraform init` (backend blocks cannot use variables).
  # No DynamoDB table: state locking uses an S3 lock file instead (Terraform >= 1.10).
  backend "s3" {
    bucket       = "devopsapp-terraform-state"
    key          = "eks/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.cluster_name
      ManagedBy = "terraform"
    }
  }
}
