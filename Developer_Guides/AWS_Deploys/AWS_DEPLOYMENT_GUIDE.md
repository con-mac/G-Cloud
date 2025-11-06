# AWS Deployment Guide

## Overview
This guide explains how to deploy the G-Cloud Proposal Automation System to AWS while keeping the local development version working.

## Architecture

### AWS Services Used
- **S3**: Static website hosting (frontend), document storage (SharePoint mock), templates, output
- **Lambda**: Serverless compute for API and PDF conversion
- **API Gateway**: HTTP API endpoint
- **CloudFront**: CDN for frontend (optional but recommended)
- **IAM**: Roles and policies for Lambda functions

### Cost Optimization
- **S3**: Very cheap for storage (~$0.023/GB/month)
- **CloudFront**: Free tier (1TB transfer/month)
- **Lambda**: Free tier (1M requests/month)
- **API Gateway**: Free tier (1M requests/month)
- **Total Estimated Cost**: < $10/month for low traffic

## Deployment Strategy

### Environment Variable: USE_S3
The system uses the `USE_S3` environment variable to switch between local and AWS storage:

- **Local Development**: `USE_S3=false` (or not set) → Uses `mock_sharepoint` (local file system)
- **AWS Deployment**: `USE_S3=true` → Uses `s3_sharepoint` (S3 bucket)

### Service Abstraction Layer
The `sharepoint_service.py` module automatically switches between:
- `mock_sharepoint.py` (local file system)
- `s3_sharepoint.py` (S3 bucket)

All backend code uses `sharepoint_service` which handles the switching automatically.

## S3 Bucket Structure

The SharePoint mock structure is mirrored in S3:

```
sharepoint-bucket/
├── GCloud 14/
│   └── PA Services/
│       ├── Cloud Support Services LOT 2/
│       │   └── [Service Name]/
│       │       ├── OWNER [Name].txt
│       │       ├── PA GC14 SERVICE DESC [Service Name].docx
│       │       └── PA GC14 Pricing Doc [Service Name].docx
│       └── Cloud Support Services LOT 3/
│           └── [Service Name]/
│               └── ...
└── GCloud 15/
    └── PA Services/
        ├── Cloud Support Services LOT 2/
        └── Cloud Support Services LOT 3/
```

## Deployment Steps

### 1. Prerequisites
```bash
# Install AWS CLI
aws --version

# Install Terraform
terraform --version

# Configure AWS credentials
aws configure
```

### 2. Update Terraform Variables
Edit `infrastructure/terraform/aws/variables.tf` or create `terraform.tfvars`:

```hcl
project_name = "gcloud-automation"
environment = "dev"
aws_region = "eu-west-2"
app_secret_key = "your-secret-key-here"
enable_cloudfront = true
```

### 3. Deploy Infrastructure
```bash
cd infrastructure/terraform/aws
terraform init
terraform plan
terraform apply
```

### 4. Upload Initial Data to S3
```bash
# Upload SharePoint mock data to S3
aws s3 sync mock_sharepoint/ s3://[sharepoint-bucket-name]/ --exclude "*.git/*"

# Upload templates to S3
aws s3 cp backend/templates/service_description_template.docx s3://[templates-bucket-name]/templates/
```

### 5. Deploy Lambda Functions
```bash
# Deploy API Lambda
cd backend
zip -r lambda-package.zip . -x "*.git*" -x "*__pycache__*" -x "*.pyc"
aws s3 cp lambda-package.zip s3://[lambda-deploy-bucket-name]/
# Update Lambda function code via Terraform or AWS Console

# Deploy PDF Converter Lambda (Docker image)
cd pdf_converter
docker build -t pdf-converter .
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin [ecr-repo-url]
docker tag pdf-converter:latest [ecr-repo-url]:latest
docker push [ecr-repo-url]:latest
```

### 6. Deploy Frontend
```bash
# Build frontend with API Gateway URL
export VITE_API_BASE_URL=$(terraform output -raw api_gateway_url)
cd frontend
npm run build

# Deploy to S3
aws s3 sync dist/ s3://[frontend-bucket-name]/ --delete
```

## Environment Variables

### Lambda Functions
The following environment variables are set in Terraform:

- `USE_S3=true`
- `TEMPLATE_BUCKET_NAME`: S3 bucket for templates
- `OUTPUT_BUCKET_NAME`: S3 bucket for generated documents
- `UPLOAD_BUCKET_NAME`: S3 bucket for uploads
- `SHAREPOINT_BUCKET_NAME`: S3 bucket for SharePoint documents
- `TEMPLATE_S3_KEY`: S3 key for template file
- `PDF_CONVERTER_FUNCTION_NAME`: Lambda function name for PDF converter
- `CORS_ORIGINS`: Allowed CORS origins

### Local Development
For local development, these environment variables are not set (or `USE_S3=false`), so the system uses local file system.

## Testing

### Local Testing
```bash
# Start backend (uses local file system)
cd backend
uvicorn app.main:app --reload

# Start frontend
cd frontend
npm run dev
```

### AWS Testing
1. Deploy to AWS using steps above
2. Access frontend via CloudFront URL or S3 website endpoint
3. Test all functionality:
   - Login
   - Create proposal
   - Update proposal
   - Generate documents
   - Download documents

## Migration from Local to AWS

### Step 1: Upload Existing Data
```bash
# Upload mock SharePoint data
aws s3 sync mock_sharepoint/ s3://[sharepoint-bucket-name]/
```

### Step 2: Update Environment Variables
Set `USE_S3=true` in Lambda environment variables (via Terraform).

### Step 3: Test
Verify all functionality works with S3 storage.

## Troubleshooting

### Issue: Lambda can't access S3
**Solution**: Check IAM role has S3 permissions for the SharePoint bucket.

### Issue: Documents not found
**Solution**: Verify S3 bucket structure matches local `mock_sharepoint` structure.

### Issue: CORS errors
**Solution**: Check `CORS_ORIGINS` environment variable includes frontend URL.

## Cost Monitoring

### AWS Cost Explorer
Monitor costs via AWS Cost Explorer:
- S3 storage costs
- Lambda invocation costs
- API Gateway request costs
- CloudFront transfer costs

### Estimated Monthly Costs (Low Traffic)
- S3 Storage (10GB): ~$0.23
- Lambda (1000 invocations): Free (within free tier)
- API Gateway (1000 requests): Free (within free tier)
- CloudFront (10GB transfer): Free (within free tier)
- **Total**: < $1/month

## Next Steps

### Azure Migration
When ready to migrate to Azure:
1. Create Azure Blob Storage containers
2. Migrate S3 data to Azure Blob Storage
3. Update backend to use Azure Blob Storage SDK
4. Deploy to Azure Functions or App Service
5. Update frontend to use Azure Static Web Apps

## References

- [Terraform Configuration](../infrastructure/terraform/aws/)
- [S3 Service Implementation](../backend/sharepoint_service/s3_sharepoint.py)
- [Service Abstraction Layer](../backend/sharepoint_service/sharepoint_service.py)
- [Cloud Hosting Guide](../CLOUD_HOSTING.md)

