# PDF Converter Lambda Deployment

## Current Status

✅ **Code Complete**: PDF converter Lambda code is ready using `python-docx` and `reportlab` (no LibreOffice needed)  
⚠️ **Deployment Issue**: Container image manifest format not supported by Lambda

## Issue

The Docker image is being built and pushed to ECR successfully, but Lambda reports:
```
InvalidParameterValueException: The image manifest, config or layer media type for the source image ... is not supported.
```

## Solution Options

### Option 1: Fix Container Image Format (Recommended)

The Lambda base image might require a specific Docker manifest format. Try:

1. **Use Docker BuildKit with OCI format:**
```bash
export DOCKER_BUILDKIT=1
docker build --platform linux/amd64 --output type=docker -t gcloud-automation-dev-pdf-converter:latest .
```

2. **Or rebuild using AWS ECR's build service:**
```bash
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 535002854646.dkr.ecr.eu-west-2.amazonaws.com
docker buildx build --platform linux/amd64 --push -t 535002854646.dkr.ecr.eu-west-2.amazonaws.com/gcloud-automation-dev-pdf-converter:latest .
```

### Option 2: Use ZIP Package Instead of Container

Convert the PDF converter to a regular Lambda function (not container-based):

1. Update `infrastructure/terraform/aws/main.tf`:
   - Change `package_type = "Image"` to `package_type = "Zip"`
   - Remove `image_uri` and add `handler = "pdf_converter.handler"`
   - Add `runtime = "python3.10"`
   - Point to S3 zip file instead

2. Create deployment package:
```bash
cd backend/pdf_converter
zip -r pdf-converter.zip . -x "*.pyc" "__pycache__/*"
aws s3 cp pdf-converter.zip s3://gcloud-automation-dev-lambda-deploy/pdf-converter.zip
```

### Option 3: Temporary Workaround

For now, PDF generation gracefully fails and returns the S3 key as a placeholder. Users will get Word documents, and PDF generation can be added later when the container issue is resolved.

## Files

- `backend/pdf_converter/Dockerfile` - Container image definition
- `backend/pdf_converter/pdf_converter.py` - Lambda handler (uses python-docx + reportlab)
- `backend/pdf_converter/requirements.txt` - Python dependencies
- `infrastructure/terraform/aws/main.tf` - Terraform config for PDF converter Lambda

## Testing

Once deployed, test with:
```bash
curl -X POST "https://jqms1xopz9.execute-api.eu-west-2.amazonaws.com/api/v1/templates/service-description/generate" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test description","features":["Feature"],"benefits":["Benefit"],"service_definition":[]}'
```

Check the `pdf_path` in the response - it should be a valid S3 presigned URL if PDF generation is working.

