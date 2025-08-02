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

variable "version_count" {
  description = "Number of versions to retain for S3 objects. Set to 0 to disable versioning entirely"
  type        = number
  default     = 5
  
  validation {
    condition     = var.version_count >= 0
    error_message = "Version count must be 0 or greater. Use 0 to disable versioning."
  }
}

variable "version_retention_days" {
  description = "Number of days to retain non-current versions of S3 objects"
  type        = number
  default     = 30
  
  validation {
    condition     = var.version_retention_days > 0
    error_message = "Version retention days must be greater than 0."
  }
}
