terraform {
  required_providers {
    aws = {
      version = "~> 4.1"
      source  = "hashicorp/aws"
    }

    tls = {
      version = "4.0.4"
      source  = "hashicorp/tls"
    }

    cloudinit = {
      version = "2.2.0"
      source  = "hashicorp/cloudinit"
    }

    # kubernetes = {
    #   version = ">= 2.10"
    #   source  = "hashicorp/kubernetes"
    # }

    # helm = {
    #   source  = "hashicorp/helm"
    #   version = ">= 2.4.1"
    # }

    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = ">= 1.7.0"
    # }

    environment = {
      source  = "EppO/environment"
      version = "~> 1.3"
    }

    # random = {
    #   source  = "hashicorp/random"
    #   version = ">= 3.4.3"
    # }
  }
}

data "environment_variables" "all" {}

provider "aws" {
  region = var.region

  assume_role_with_web_identity {
    role_arn           = "arn:aws:iam::${var.aws_account}:role/${var.iam_role}"
    web_identity_token = data.environment_variables.all.items["TFC_WORKLOAD_IDENTITY_TOKEN"]
  }

  default_tags {
    tags = {
      Created_by = "Terraform"
      Project    = "TechTalks"
    }
  }
}

# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   token                  = data.aws_eks_cluster_auth.cluster.token
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

#   experiments {
#     manifest_resource = true
#   }
# }

# provider "helm" {
#   kubernetes {
#     host                   = data.aws_eks_cluster.cluster.endpoint
#     token                  = data.aws_eks_cluster_auth.cluster.token
#     cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#   }
# }

# provider "kubectl" {
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   token                  = data.aws_eks_cluster_auth.cluster.token
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
#   load_config_file       = false
# }
