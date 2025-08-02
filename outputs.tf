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
