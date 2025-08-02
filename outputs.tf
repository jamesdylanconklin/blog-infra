# outputs.tf

# For direct testing and debugging
output "content_bucket_name" {
  description = "Name of the S3 bucket for blog content"
  value       = aws_s3_bucket.content.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = aws_cloudfront_distribution.content.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.content.domain_name
}

output "website_url" {
  description = "Primary website URL"
  value       = "https://${aws_cloudfront_distribution.content.domain_name}"
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions deployment"
  value       = aws_iam_role.github_actions.arn
}

# Parameter Store parameter names for cross-repository reference
output "parameter_content_bucket_name" {
  description = "Parameter Store parameter name for content bucket"
  value       = aws_ssm_parameter.content_bucket_name.name
}

output "parameter_cloudfront_distribution_id" {
  description = "Parameter Store parameter name for CloudFront distribution ID"
  value       = aws_ssm_parameter.cloudfront_distribution_id.name
}

output "parameter_website_url" {
  description = "Parameter Store parameter name for website URL"
  value       = aws_ssm_parameter.website_url.name
}

output "parameter_github_actions_role_arn" {
  description = "Parameter Store parameter name for GitHub Actions role ARN"
  value       = aws_ssm_parameter.github_actions_role_arn.name
}
