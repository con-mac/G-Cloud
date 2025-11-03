# AWS Lambda + S3 Deployment

This directory contains Terraform configuration for deploying the G-Cloud Proposal Automation System to AWS using Lambda and S3.

## Architecture

- **Frontend**: React SPA hosted on S3 (static website hosting) with optional CloudFront CDN
- **Backend API**: FastAPI application running on AWS Lambda
- **API Gateway**: HTTP API Gateway that triggers Lambda functions
- **S3 Buckets**:
  - `*-frontend`: Static website hosting for React frontend
  - `*-templates`: Stores Word document templates (private)
  - `*-output`: Stores generated documents (private, presigned URLs)
  - `*-uploads`: Stores uploaded files (private, temporary)
  - `*-lambda-deploy`: Stores Lambda deployment packages

## Prerequisites

1. AWS CLI configured with credentials
2. Terraform >= 1.0 installed
3. Python 3.12+ for Lambda packaging
4. Node.js and npm for frontend build

## Deployment Steps

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_name    = "gcloud-automation"
environment     = "dev"
aws_region      = "eu-west-2"
app_secret_key  = "your-secret-key-here"
enable_cloudfront = true
lambda_deploy_s3_key = "lambda-package.zip"
```

### 2. Upload Template

Before deploying, ensure your template is ready:

```bash
aws s3 cp docs/service_description_template.docx \
  s3://<template-bucket>/templates/service_description_template.docx
```

### 3. Deploy Infrastructure

```bash
cd infrastructure/terraform/aws
terraform init
terraform plan
terraform apply
```

### 4. Package and Deploy Lambda

```bash
# From project root
./scripts/deploy-lambda.sh dev
```

### 5. Deploy Frontend

```bash
# Get API Gateway URL from Terraform output
API_GATEWAY_URL=$(terraform -chdir=infrastructure/terraform/aws output -raw api_gateway_url)

# Deploy frontend
./scripts/deploy-frontend.sh dev ${API_GATEWAY_URL}
```

### 6. Complete Deployment (All-in-One)

```bash
# From project root
./scripts/deploy-all.sh dev
```

## Environment Variables

Lambda function uses these environment variables:

- `USE_S3=true` - Enable S3 operations
- `TEMPLATE_BUCKET_NAME` - S3 bucket for templates
- `OUTPUT_BUCKET_NAME` - S3 bucket for generated documents
- `UPLOAD_BUCKET_NAME` - S3 bucket for uploads
- `TEMPLATE_S3_KEY` - S3 key for template (default: `templates/service_description_template.docx`)
- `SECRET_KEY` - Application secret key
- `ENVIRONMENT` - Environment name
- `DEBUG` - Debug mode (true/false)

## Frontend Configuration

Update frontend `.env` or build-time variables:

```bash
VITE_API_BASE_URL=https://<api-gateway-url>
```

Or set during build:

```bash
VITE_API_BASE_URL=https://<api-gateway-url> npm run build
```

## Costs

Estimated monthly costs (UK regions, low-medium traffic):

- Lambda: ~£0.20 per million requests (first 1M free)
- API Gateway: ~£2.50 per million requests (first 1M free)
- S3 Storage: ~£0.023 per GB
- S3 Requests: ~£0.004 per 1,000 requests
- CloudFront: ~£0.06 per GB transfer (first 1TB free)

Total: ~£5-10/month for low traffic development environment

## Troubleshooting

### Lambda timeout
Increase timeout in `main.tf`:
```hcl
timeout = 120  # seconds
```

### Lambda memory
Increase memory in `main.tf`:
```hcl
memory_size = 2048  # MB
```

### Frontend not loading
Check S3 bucket policy allows public read access.

### API Gateway CORS errors
Ensure CORS is configured in `main.tf` and frontend URL is whitelisted.

### Template not found
Verify template is uploaded to S3:
```bash
aws s3 ls s3://<template-bucket>/templates/
```

## Cleanup

```bash
cd infrastructure/terraform/aws
terraform destroy
```

**Note**: This will delete all resources including S3 buckets and their contents.

