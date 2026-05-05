# =============================================================================
# Variables — ShopSmart Infrastructure
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "shopsmart"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 5001
}

variable "lab_role_arn" {
  description = "ARN of the AWS Academy LabRole (pre-existing IAM role)"
  type        = string
}

variable "ecr_image" {
  description = "Full ECR image URI (repo:tag). Leave empty to use default latest tag."
  type        = string
  default     = ""
}
