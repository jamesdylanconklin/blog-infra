# Blog Infrastructure

Simple architecture for serving static blog content.

## Goals

- Continue learning Terraform, with a tighter focus on best practices than my first explorations
- Maintain a simple architecture for serving blog content
  - Pull bucket name, domain name from vars and publish to Param Store for configured environment and project.
    - Check for collision among other environments. We should have separate subdomains for each env.
  - S3 bucket to hold TF state
    - env-independent bucket name, env-dependent keys for state objects.
    Private ()
  - Private S3 bucket for static content
    - Private (OAC limited to CF and deploy role for blog-content deploy)
    - deletes not protected
    - var-configurable number of retained versions and retention period for non-current versions.
  - Cloudfront to serve and cache bucket content
    - Set reasonable cache TTLs for assets, articles
      - Lower for HTML
      - Higher for assets
      - Midrange for sitemap
    - SSL Termination
    - Output distribution ID to Parameter Store for use by content publisher.
    - Redirect to 404 page for s3 miss.
    - Logging/Monitoring as a later learning exercise.
  - Route53 mapping of domain to CloudFront
    - details TBD once domain transfer clears. 

## TF Inputs
- environment: string
- project_name: string
- state_bucket_name: string
- content_bucket_name: string
- domain: string (optional)

## TF outputs
- aws_ssm_parameter.content_bucket_name_param.name
- aws_ssm_parameter.domain_param.name (set to CF distribution URL if domain not specified)
- aws_ssm_parameter.cloudfront_distribution_id.name
- aws_ssm_parameter.deploy_role_arn.name
- (plus the actual relevant resources. The params are for tracking that we're pushing them for consumption by content deploy)

## Usage
TBD

## Want-to-haves
- GitHub actions to build dev resources on PR merge and prod resources on release.