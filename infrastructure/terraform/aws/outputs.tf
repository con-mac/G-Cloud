/**
 * Terraform outputs for AWS deployment
 */

output "frontend_url" {
  description = "URL for frontend (S3 website or CloudFront)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.frontend[0].domain_name : aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "frontend_s3_bucket" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.id
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.api.function_name
}

output "template_bucket" {
  description = "S3 bucket name for templates"
  value       = aws_s3_bucket.templates.id
}

output "output_bucket" {
  description = "S3 bucket name for generated documents"
  value       = aws_s3_bucket.output.id
}

output "upload_bucket" {
  description = "S3 bucket name for uploads"
  value       = aws_s3_bucket.uploads.id
}

