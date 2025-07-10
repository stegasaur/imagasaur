output "uploads_bucket_name" {
  description = "The name of the uploads S3 bucket"
  value       = module.s3.uploads_bucket_name
}

output "processed_bucket_name" {
  description = "The name of the processed S3 bucket"
  value       = module.s3.processed_bucket_name
}

output "frontend_bucket_name" {
  description = "The name of the frontend S3 bucket"
  value       = module.s3.frontend_bucket_name
}

output "api_gateway_url" {
  description = "The base URL of the API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.upload_function.function_name
}

output "lambda_invoke_arn" {
  description = "The ARN to be used for invoking Lambda function from API Gateway"
  value       = aws_lambda_function.upload_function.invoke_arn
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = module.cloudfront.cloudfront_domain_name
}
