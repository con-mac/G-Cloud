# AWS Lambda + S3 Migration Guide

This guide explains how to migrate your G-Cloud Proposal Automation System from Docker Compose to AWS Lambda and S3.

## Overview

The migration moves:
- **Frontend**: From Docker container → S3 static website hosting (with optional CloudFront CDN)
- **Backend API**: From FastAPI container → AWS Lambda (via Mangum adapter)
- **Storage**: From local filesystem → S3 buckets (templates, generated docs, uploads)
- **Infrastructure**: From Docker Compose → Terraform-managed AWS resources

## Architecture

```
User → CloudFront/S3 (Frontend) → API Gateway → Lambda → S3 Buckets
                                           ↓
                                     (Document Generation)
```

## Key Components

### 1. Lambda Function
- **Handler**: `lambda_handler.handler` (wraps FastAPI with Mangum)
- **Runtime**: Python 3.12
- **Memory**: 1024 MB (configurable)
- **Timeout**: 60 seconds (configurable)
- **Environment Variables**:
  - `USE_S3=true` - Enables S3 operations
  - `TEMPLATE_BUCKET_NAME` - S3 bucket for templates
  - `OUTPUT_BUCKET_NAME` - S3 bucket for generated documents
  - `UPLOAD_BUCKET_NAME` - S3 bucket for uploads
  - `TEMPLATE_S3_KEY` - S3 key for template (default: `templates/service_description_template.docx`)

### 2. S3 Buckets
- **Frontend**: Public read, static website hosting
- **Templates**: Private, versioned
- **Output**: Private, versioned (generated documents)
- **Uploads**: Private, 7-day lifecycle policy
- **Lambda Deploy**: Private (deployment packages)

### 3. API Gateway
- **Type**: HTTP API (cost-effective)
- **CORS**: Configured for all origins
- **Integration**: Lambda proxy integration
- **Routes**: All requests (`$default`) → Lambda function

### 4. CloudFront (Optional)
- CDN for frontend S3 bucket
- SSL/HTTPS by default
- Cache policies configured
- SPA-friendly error handling (404 → index.html)

## Migration Steps

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured: `aws configure`
3. **Terraform** >= 1.0 installed
4. **Python** 3.12+ for Lambda packaging
5. **Node.js** and npm for frontend build

### Step 1: Install Dependencies

```bash
# Backend dependencies (including Mangum and boto3)
cd backend
pip install -r requirements.txt
```

### Step 2: Prepare Template

Upload your template to S3 (or do this via Terraform after infrastructure is created):

```bash
aws s3 cp docs/service_description_template.docx \
  s3://<template-bucket>/templates/service_description_template.docx
```

### Step 3: Deploy Infrastructure

```bash
cd infrastructure/terraform/aws

# Initialize Terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_name    = "gcloud-automation"
environment     = "dev"
aws_region      = "eu-west-2"
app_secret_key  = "your-secret-key-here"
enable_cloudfront = true
lambda_deploy_s3_key = "lambda-package.zip"
EOF

# Plan deployment
terraform plan

# Apply (creates all AWS resources)
terraform apply
```

### Step 4: Package and Deploy Lambda

```bash
# From project root
./scripts/deploy-lambda.sh dev
```

This script:
1. Installs Python dependencies
2. Copies application code
3. Creates Lambda deployment package (ZIP)
4. Uploads to S3 deployment bucket

### Step 5: Deploy Frontend

```bash
# Get API Gateway URL from Terraform output
API_GATEWAY_URL=$(terraform -chdir=infrastructure/terraform/aws output -raw api_gateway_url)

# Deploy frontend
./scripts/deploy-frontend.sh dev ${API_GATEWAY_URL}
```

Or use the all-in-one script:

```bash
./scripts/deploy-all.sh dev
```

## Code Changes

### Backend Changes

1. **Lambda Handler** (`backend/app/lambda_handler.py`)
   - Wraps FastAPI app with Mangum adapter
   - Entry point for Lambda invocations

2. **S3 Service** (`backend/app/services/s3_service.py`)
   - Handles S3 operations (download templates, upload documents, presigned URLs)
   - Used when `USE_S3=true`

3. **Document Generator** (`backend/app/services/document_generator.py`)
   - Modified to support S3 when `s3_service` is provided
   - Downloads templates from S3 to `/tmp`
   - Uploads generated documents to S3
   - Returns presigned URLs for downloads

4. **API Routes** (`backend/app/api/routes/templates.py`)
   - Detects S3 environment via `USE_S3` env var
   - Returns presigned URLs for downloads when using S3
   - Uploads files to S3 instead of local filesystem

### Frontend Changes

1. **API Service** (`frontend/src/services/api.ts`)
   - Supports both `VITE_API_BASE_URL` (AWS) and `VITE_API_URL` (Docker)
   - Works with both API Gateway URLs and local Docker URLs

2. **Build Configuration**
   - Set `VITE_API_BASE_URL` environment variable during build
   - Example: `VITE_API_BASE_URL=https://abc123.execute-api.eu-west-2.amazonaws.com npm run build`

## Environment Variables

### Lambda Function
Set via Terraform in `main.tf`:
```hcl
environment {
  variables = {
    USE_S3                = "true"
    TEMPLATE_BUCKET_NAME   = aws_s3_bucket.templates.id
    OUTPUT_BUCKET_NAME     = aws_s3_bucket.output.id
    UPLOAD_BUCKET_NAME     = aws_s3_bucket.uploads.id
    TEMPLATE_S3_KEY        = "templates/service_description_template.docx"
    SECRET_KEY             = var.app_secret_key
    ENVIRONMENT            = var.environment
    DEBUG                  = var.environment == "dev" ? "true" : "false"
  }
}
```

### Frontend Build
Set during build process:
```bash
VITE_API_BASE_URL=https://<api-gateway-url> npm run build
```

Or in `.env` file:
```bash
VITE_API_BASE_URL=https://abc123.execute-api.eu-west-2.amazonaws.com
```

## Testing

### Local Testing with S3

You can test S3 functionality locally:

```bash
# Set environment variables
export USE_S3=true
export TEMPLATE_BUCKET_NAME=your-bucket
export OUTPUT_BUCKET_NAME=your-output-bucket
export UPLOAD_BUCKET_NAME=your-upload-bucket
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=eu-west-2

# Run FastAPI locally
cd backend
uvicorn app.main:app --reload
```

### Testing Lambda Locally

Use `sam local` or `lambda-local` for local Lambda testing:

```bash
# Install SAM CLI
pip install aws-sam-cli

# Test locally
sam local start-api --template template.yaml
```

## Deployment Workflow

### Initial Deployment

1. Deploy infrastructure with Terraform
2. Upload template to S3
3. Package and deploy Lambda
4. Build and deploy frontend
5. Test end-to-end

### Updates

**Backend Updates:**
```bash
# Re-package and deploy Lambda
./scripts/deploy-lambda.sh dev

# Lambda function will auto-update from S3
```

**Frontend Updates:**
```bash
# Re-build and deploy
./scripts/deploy-frontend.sh dev ${API_GATEWAY_URL}
```

**Infrastructure Updates:**
```bash
cd infrastructure/terraform/aws
terraform plan
terraform apply
```

## Monitoring and Logs

### Lambda Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/<function-name> --follow
```

### API Gateway Logs
Enable CloudWatch Logs in API Gateway console or via Terraform.

### S3 Access Logs
Enable S3 access logging in bucket configuration.

## Cost Optimization

1. **Lambda**: Use appropriate memory (start with 1024 MB, reduce if needed)
2. **S3**: Use lifecycle policies for uploads (auto-delete after 7 days)
3. **API Gateway**: Use HTTP API (cheaper than REST API)
4. **CloudFront**: Use appropriate cache policies
5. **Terraform State**: Use S3 backend for Terraform state (not included)

## Troubleshooting

### Lambda Timeout
Increase timeout in `infrastructure/terraform/aws/main.tf`:
```hcl
timeout = 120  # seconds
```

### Lambda Memory
Increase memory if document generation is slow:
```hcl
memory_size = 2048  # MB
```

### CORS Errors
Ensure CORS is configured in:
1. API Gateway (`main.tf` - `cors_configuration`)
2. Lambda function (FastAPI CORS middleware)
3. S3 bucket policies (if serving files directly)

### Template Not Found
Verify template is uploaded:
```bash
aws s3 ls s3://<template-bucket>/templates/
```

### Frontend Not Loading
Check:
1. S3 bucket policy allows public read
2. CloudFront distribution is enabled (if using)
3. Index document is configured correctly

### API Gateway 502/503
Check Lambda logs:
```bash
aws logs tail /aws/lambda/<function-name> --follow
```

Common issues:
- Lambda timeout (increase timeout)
- Lambda out of memory (increase memory)
- Missing environment variables
- IAM permissions (check Lambda execution role)

## Rollback

To rollback to Docker Compose:

1. Keep Docker Compose setup intact (this migration doesn't modify it)
2. Update frontend `.env` to use Docker API URL
3. Restart Docker Compose services

## Next Steps

After successful migration:
1. Set up custom domain for CloudFront
2. Configure SSL certificate
3. Set up CI/CD pipeline for automatic deployments
4. Configure monitoring and alerting
5. Set up backup/restore procedures for S3 buckets

## Support

For issues or questions:
1. Check AWS CloudWatch logs
2. Check Terraform state: `terraform state list`
3. Verify IAM permissions
4. Test Lambda locally using SAM CLI

