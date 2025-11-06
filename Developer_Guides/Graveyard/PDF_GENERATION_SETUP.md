# PDF Generation Setup Guide

This guide explains how to deploy and use the PDF converter Lambda function.

## Architecture

The PDF generation system uses a separate Lambda function (container-based) to convert Word documents to PDF using LibreOffice. This keeps the main API Lambda lightweight while handling the resource-intensive PDF conversion separately.

### Components

1. **PDF Converter Lambda** - Container-based Lambda function with LibreOffice installed
2. **ECR Repository** - Stores the Docker image for the PDF converter
3. **Main API Lambda** - Invokes the PDF converter after generating Word documents

## Deployment Steps

### 1. Deploy Infrastructure (Terraform)

First, deploy the Terraform infrastructure which creates:
- ECR repository for the container image
- PDF converter Lambda function (container-based)
- IAM roles and permissions

```bash
cd infrastructure/terraform/aws
terraform apply
```

### 2. Build and Deploy Container Image

Build the Docker image and push it to ECR:

```bash
./scripts/deploy-pdf-converter.sh dev
```

This script:
- Builds the Docker image with LibreOffice
- Pushes it to the ECR repository
- Updates the Lambda function to use the new image

### 3. Deploy Main API Lambda

The main API Lambda needs to be updated to include permission to invoke the PDF converter:

```bash
cd infrastructure/terraform/aws
terraform apply -target=aws_lambda_function.api
```

Then redeploy the Lambda package:

```bash
./scripts/deploy-lambda.sh dev
aws lambda update-function-code --function-name gcloud-automation-dev-api --s3-bucket gcloud-automation-dev-lambda-deploy --s3-key lambda-package.zip --region eu-west-2
```

## How It Works

1. User submits form to generate documents
2. Main API Lambda generates Word document and uploads to S3
3. Main API Lambda invokes PDF converter Lambda synchronously
4. PDF converter Lambda:
   - Downloads Word document from S3
   - Converts to PDF using LibreOffice headless
   - Uploads PDF back to S3
   - Returns presigned URL for PDF
5. Main API Lambda returns both Word and PDF URLs to frontend

## Troubleshooting

### Container Build Fails

If the Docker build fails, ensure:
- Docker is installed and running
- AWS credentials are configured
- ECR repository exists (created by Terraform)

### PDF Conversion Fails

Check CloudWatch logs for the PDF converter Lambda:
```bash
aws logs tail /aws/lambda/gcloud-automation-dev-pdf-converter --follow
```

Common issues:
- LibreOffice not found: Check Dockerfile installation
- S3 permissions: Verify IAM role has S3 access
- Timeout: PDF conversion may take time - Lambda timeout is set to 5 minutes

### Lambda Invocation Fails

If the main API Lambda can't invoke the PDF converter:
- Check IAM permissions (lambda:InvokeFunction)
- Verify PDF_CONVERTER_FUNCTION_NAME environment variable is set
- Check that PDF converter Lambda function name matches

## Notes

- PDF conversion is synchronous - the API waits for PDF generation
- If PDF conversion fails, the API still returns the Word document
- The container image can be up to 10GB (Lambda container limit)
- LibreOffice headless mode doesn't require a display server

