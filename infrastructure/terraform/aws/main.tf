/**
 * AWS Terraform configuration for Lambda + S3 deployment
 * G-Cloud Proposal Automation System
 */

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# S3 Bucket for Frontend (Static Website Hosting)
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-${var.environment}-frontend"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "PublicReadGetObject"
          Effect    = "Allow"
          Principal = "*"
          Action    = "s3:GetObject"
          Resource  = "${aws_s3_bucket.frontend.arn}/*"
        }
      ],
      var.enable_cloudfront ? [
        {
          Sid       = "CloudFrontOACAccess"
          Effect    = "Allow"
          Principal = {
            Service = "cloudfront.amazonaws.com"
          }
          Action   = "s3:GetObject"
          Resource = "${aws_s3_bucket.frontend.arn}/*"
          Condition = {
            StringEquals = {
              "AWS:SourceArn" = aws_cloudfront_distribution.frontend[0].arn
            }
          }
        }
      ] : []
    )
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend
  ]
}

# S3 Bucket for Templates (Private)
resource "aws_s3_bucket" "templates" {
  bucket = "${var.project_name}-${var.environment}-templates"
}

resource "aws_s3_bucket_versioning" "templates" {
  bucket = aws_s3_bucket.templates.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for Generated Documents (Private)
resource "aws_s3_bucket" "output" {
  bucket = "${var.project_name}-${var.environment}-output"
}

resource "aws_s3_bucket_versioning" "output" {
  bucket = aws_s3_bucket.output.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for Uploads (Private)
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-${var.environment}-uploads"
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "delete-old-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7  # Delete uploads after 7 days
    }
  }
}

# S3 Bucket for Lambda Deployment Package
resource "aws_s3_bucket" "lambda_deploy" {
  bucket = "${var.project_name}-${var.environment}-lambda-deploy"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-${var.environment}-lambda-s3-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.templates.arn}/*",
          "${aws_s3_bucket.output.arn}/*",
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.templates.arn,
          aws_s3_bucket.output.arn,
          aws_s3_bucket.uploads.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.pdf_converter.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  handler       = "app.lambda_handler.handler"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda.arn
  timeout       = 60
  memory_size   = 1024

  s3_bucket = aws_s3_bucket.lambda_deploy.id
  s3_key    = var.lambda_deploy_s3_key

  environment {
    variables = {
      USE_S3                      = "true"
      TEMPLATE_BUCKET_NAME        = aws_s3_bucket.templates.id
      OUTPUT_BUCKET_NAME          = aws_s3_bucket.output.id
      UPLOAD_BUCKET_NAME          = aws_s3_bucket.uploads.id
      TEMPLATE_S3_KEY             = "templates/service_description_template.docx"
      PDF_CONVERTER_FUNCTION_NAME = try(aws_lambda_function.pdf_converter.function_name, "")
      SECRET_KEY                  = var.app_secret_key
      ENVIRONMENT                 = var.environment
      DEBUG                       = var.environment == "dev" ? "true" : "false"
      # CORS origins - allow CloudFront and S3 website endpoints
      CORS_ORIGINS                = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
      # Optional fields for Lambda (not needed for document generation)
      DATABASE_URL                = ""
      AZURE_AD_TENANT_ID          = ""
      AZURE_AD_CLIENT_ID          = ""
      AZURE_AD_CLIENT_SECRET      = ""
      AZURE_STORAGE_CONNECTION_STRING = ""
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_s3
  ]
}

# ECR Repository for PDF Converter Container
resource "aws_ecr_repository" "pdf_converter" {
  name                 = "${var.project_name}-${var.environment}-pdf-converter"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role for PDF Converter Lambda
resource "aws_iam_role" "pdf_converter_lambda" {
  name = "${var.project_name}-${var.environment}-pdf-converter-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "pdf_converter_lambda_s3" {
  name = "${var.project_name}-${var.environment}-pdf-converter-lambda-s3-policy"
  role = aws_iam_role.pdf_converter_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.output.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# PDF Converter Lambda Function (Container Image)
resource "aws_lambda_function" "pdf_converter" {
  function_name = "${var.project_name}-${var.environment}-pdf-converter"
  role          = aws_iam_role.pdf_converter_lambda.arn
  timeout       = 300  # 5 minutes for PDF conversion
  memory_size   = 1024

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.pdf_converter.repository_url}:latest"

  environment {
    variables = {
      OUTPUT_BUCKET_NAME = aws_s3_bucket.output.id
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.pdf_converter_lambda_s3
  ]
}

# Grant main API Lambda permission to invoke PDF converter
resource "aws_lambda_permission" "allow_api_invoke_pdf_converter" {
  statement_id  = "AllowAPILambdaInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_converter.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = aws_lambda_function.api.arn
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.api.id

  integration_uri    = aws_lambda_function.api.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# CloudFront Origin Access Control (for S3 bucket access)
resource "aws_cloudfront_origin_access_control" "frontend" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution for Frontend (Optional but recommended)
resource "aws_cloudfront_distribution" "frontend" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend[0].id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
}

