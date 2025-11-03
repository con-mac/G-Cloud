/**
 * Terraform variables for AWS deployment
 */

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "gcloud-automation"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-2"  # London
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "G-Cloud Automation"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

variable "lambda_deploy_s3_key" {
  description = "S3 key for Lambda deployment package (e.g., 'lambda-package.zip')"
  type        = string
  default     = "lambda-package.zip"
}

variable "app_secret_key" {
  description = "Application secret key"
  type        = string
  sensitive   = true
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution for frontend"
  type        = bool
  default     = true
}

