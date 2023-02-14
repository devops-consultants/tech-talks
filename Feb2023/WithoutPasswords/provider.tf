terraform {
  required_providers {
    aws = {
      version = "~> 4.1"
      source  = "hashicorp/aws"
    }

    environment = {
      source  = "EppO/environment"
      version = "~> 1.3"
    }
  }
}


provider "aws" {
  region = var.region

  assume_role_with_web_identity {
    role_arn           = local.role_arn
    web_identity_token = data.environment_variables.all.items["TFC_WORKLOAD_IDENTITY_TOKEN"]
  }

  default_tags {
    tags = {
      Created_by  = "Terraform"
      Project     = "TechTalks"
      Environment = var.environment
    }
  }
}

data "environment_variables" "all" {}
