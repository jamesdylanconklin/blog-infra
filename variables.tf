variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
}

variable "content_bucket_name" {
  description = "Name of the S3 bucket to store blog content"
  type        = string
}

variable "domain" {
  description = "Domain name for the blog (optional). If not provided, CloudFront distribution URL will be used"
  type        = string
  default     = ""
}
