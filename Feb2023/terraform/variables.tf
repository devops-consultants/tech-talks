variable "aws_account" {
  description = "AWS Account ID"
  type        = string
}

variable "dns_domain" {
  type        = string
  description = "TLD of Route53 Domain to use for deployments"
}

variable "dynamodb_billing_mode" {
  type        = string
  description = "DynamoDB Billing mode"
  default     = "PAY_PER_REQUEST"
}

variable "eks_cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.24"
}

variable "iam_role" {
  type        = string
  description = "AWS IAM Role ARN to assume"
  default     = "techtalks"
}

variable "region" {
  description = "The AWS Region in which you want to deploy the resources"
  type        = string
  default     = "eu-west-2"
}

variable "teleport_bucket_suffix" {
  type        = string
  description = "S3 Bucket for storing session recordings"
  default     = "teleport-sessions"
}

locals {
  cluster_issuer_name = "letsencrypt-prod-dns"
  eks_name            = "tech-talks"
  tags = {
    Created_by = "Terraform"
    Project    = "TechTalks"
  }
  teleport_bucket_name = replace("${data.aws_caller_identity.current.account_id}-${var.teleport_bucket_suffix}", "_", "-")

}
