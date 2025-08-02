terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  
  backend "s3" {
    # Backend configuration provided via partial configuration files
    # bucket, key, and region will be specified in backend-{env}.hcl files
    
    # Optional but recommended: Enable state locking with DynamoDB
    # dynamodb_table = "terraform-state-lock"
    
    # Optional: Enable encryption
    encrypt = true
    profile = "sso-admin"
  }
}

# Locals for common naming patterns and tags
locals {
  # Common resource naming: project-environment-resource
  resource_prefix = "${var.project_name}-${var.environment}"
  
  # Use custom domain if configured, otherwise CloudFront domain
  # Note: Custom domain requires Route53 resources and DNS setup (future implementation)
  primary_domain = var.domain != "" ? var.domain : aws_cloudfront_distribution.content.domain_name
  
  # Common tags to apply to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.region
  
  default_tags {
    tags = local.common_tags
  }
}

# Data source to get current AWS account info
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# S3 bucket for blog content
resource "aws_s3_bucket" "content" {
  bucket = var.content_bucket_name

  tags = local.common_tags
}

# Block all public access to content bucket (OAC only)
resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption for content bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning configuration
resource "aws_s3_bucket_versioning" "content" {
  count  = var.version_count > 0 ? 1 : 0
  bucket = aws_s3_bucket.content.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle configuration for version management
resource "aws_s3_bucket_lifecycle_configuration" "content" {
  count  = var.version_count > 0 ? 1 : 0
  bucket = aws_s3_bucket.content.id

  rule {
    id     = "manage_object_versions"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.version_retention_days
    }
  }
}

# CloudFront Origin Access Control (OAC) for S3 bucket access
resource "aws_cloudfront_origin_access_control" "content" {
  name                              = "${local.resource_prefix}-content-oac"
  description                       = "OAC for ${var.project_name} ${var.environment} content bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "content" {
  comment             = "${var.project_name} ${var.environment} blog distribution"
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"  # US, Canada, Europe only (cheapest)

  # S3 origin with OAC
  origin {
    domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.content.id
    origin_id                = "S3-${aws_s3_bucket.content.bucket}"
  }

  # Default cache behavior for all content
  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.content.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Cache settings for static content
    min_ttl     = 0
    default_ttl = 86400   # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for HTML files (shorter cache)
  ordered_cache_behavior {
    path_pattern           = "*.html"
    target_origin_id       = "S3-${aws_s3_bucket.content.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Shorter cache for HTML (more frequent updates)
    # TODO: Increase to 1-7 days once CloudFront invalidation is implemented in deployment workflow
    min_ttl     = 0
    default_ttl = 300     # 5 minutes
    max_ttl     = 86400   # 1 day
  }

  # Cache behavior for CSS files (longer cache)
  ordered_cache_behavior {
    path_pattern           = "*.css"
    target_origin_id       = "S3-${aws_s3_bucket.content.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Longer cache for CSS (less frequent updates)
    min_ttl     = 0
    default_ttl = 2592000  # 30 days
    max_ttl     = 31536000 # 1 year
  }

  # Cache behavior for JavaScript files (longer cache)
  ordered_cache_behavior {
    path_pattern           = "*.js"
    target_origin_id       = "S3-${aws_s3_bucket.content.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Longer cache for JS (less frequent updates)
    min_ttl     = 0
    default_ttl = 2592000  # 30 days
    max_ttl     = 31536000 # 1 year
  }

  # Geographic restrictions (none for now)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL certificate (CloudFront default for now, custom domain later)
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"  # Required when using cloudfront_default_certificate
  }

  # Custom error pages
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  tags = local.common_tags
}

# S3 bucket policy to allow CloudFront OAC access and GitHub Actions deployment
resource "aws_s3_bucket_policy" "content" {
  bucket = aws_s3_bucket.content.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.content.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.content.arn
          }
        }
      },
      {
        Sid    = "AllowGitHubActionsDeployment"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.github_actions.arn
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.content.arn}/*"
      },
      {
        Sid    = "AllowGitHubActionsListBucket"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.github_actions.arn
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.content.arn
      }
    ]
  })
}

# Data source for GitHub OIDC provider (assumes it exists)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM role for GitHub Actions deployment
resource "aws_iam_role" "github_actions" {
  name = "${local.resource_prefix}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow any repo under your GitHub username - adjust as needed
            "token.actions.githubusercontent.com:sub" = "repo:jamesdylanconklin/*:*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for S3 deployment permissions
resource "aws_iam_role_policy" "github_actions_s3" {
  name = "s3-deployment-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.content.arn,
          "${aws_s3_bucket.content.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for CloudFront invalidation permissions  
resource "aws_iam_role_policy" "github_actions_cloudfront" {
  name = "cloudfront-invalidation-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution",
          "cloudfront:ListDistributions"
        ]
        Resource = [
          aws_cloudfront_distribution.content.arn,
          "*"  # ListDistributions requires wildcard
        ]
      }
    ]
  })
}

# Parameter Store values for cross-repository configuration handoff
resource "aws_ssm_parameter" "content_bucket_name" {
  name  = "/${var.project_name}/${var.environment}/content/bucket-name"
  type  = "String"
  value = aws_s3_bucket.content.bucket
  
  description = "S3 bucket name for blog content storage"
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name  = "/${var.project_name}/${var.environment}/content/cloudfront-distribution-id"
  type  = "String"
  value = aws_cloudfront_distribution.content.id
  
  description = "CloudFront distribution ID for cache invalidation"
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "website_url" {
  name  = "/${var.project_name}/${var.environment}/content/website-url"
  type  = "String"
  value = "https://${local.primary_domain}"
  
  description = "Primary website URL (custom domain if configured, otherwise CloudFront distribution domain)"
  tags        = local.common_tags
}

# TODO: When Route53 resources are added, this parameter will automatically 
# switch to use the custom domain if var.domain is configured
# resource "aws_ssm_parameter" "custom_domain_url" {
#   count = var.domain != "" ? 1 : 0
#   name  = "/${var.project_name}/${var.environment}/content/custom-domain-url"
#   type  = "String"
#   value = "https://${var.domain}"
#   
#   description = "Custom domain URL (when Route53 and ACM resources are configured)"
#   tags        = local.common_tags
# }

resource "aws_ssm_parameter" "github_actions_role_arn" {
  name  = "/${var.project_name}/${var.environment}/deployment/github-actions-role-arn"
  type  = "String"
  value = aws_iam_role.github_actions.arn
  
  description = "IAM role ARN for GitHub Actions deployment"
  tags        = local.common_tags
}
