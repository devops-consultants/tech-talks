variable "aws_account" {
  description = "AWS Account ID"
  type        = string
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

