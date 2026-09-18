terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # COMMENT OUT OR DELETE THIS BLOCK FOR LOCAL S3 MOCK TESTING:
  # backend "s3" {
  #   bucket         = "aegisrag-terraform-state-prod"
  #   key            = "infrastructure/kms/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "aegisrag-tstate-locks"
  #   encrypt        = true
  # }

  # ADD THIS BLOCK: Tells Terraform to expect dynamic configuration overrides [1]
  backend "local" {}
}


variable "environment" {
  type        = string
  default     = "local"
  description = "The target cluster deployment namespace segment (local, staging, production)"
}

provider "aws" {
  region = "us-east-1"

  # Secure credential overrides for LocalStack development sandboxes
  access_key = var.environment == "local" ? "mock-access-key" : null
  secret_key = var.environment == "local" ? "mock-secret-key" : null

  # Bypass real identity handshakes when pointing to local emulators
  skip_credentials_validation = var.environment == "local"
  skip_metadata_api_check     = var.environment == "local"
  skip_requesting_account_id  = var.environment == "local"

  # Modern AWS Provider endpoint configuration block mapping
  endpoints {
    kms = var.environment == "local" ? "http://localhost:4566" : null
    iam = var.environment == "local" ? "http://localhost:4566" : null
    # ADD THIS LINE: Forces STS lookup commands to route into your local container space
    sts = var.environment == "local" ? "http://localhost:4566" : null
  }
}


