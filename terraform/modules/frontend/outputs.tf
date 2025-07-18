output "frontend_bucket" {
  description = "The frontend S3 bucket name."
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_cloudfront_distribution_hosted_zone_id" {
  description = "The hosted zone ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}
