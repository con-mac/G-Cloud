# Quick Deployment Guide - AWS Lambda + S3

This guide shows you how to deploy everything with one command and customize your deployment.

## 🚀 Quick Start (Auto-Deploy Everything)

### In Cursor Terminal (Recommended)

1. Open terminal in Cursor (`` Ctrl+` `` or `View → Terminal`)
2. Navigate to project root:
```bash
cd /home/con-mac/dev/projects/gcloud_automate
```

3. Set your customization variables (optional):
```bash
export PROJECT_NAME="my-gcloud-app"
export ENVIRONMENT="prod"
export AWS_REGION="eu-west-2"  # London
```

4. Run the all-in-one deployment script:
```bash
./scripts/deploy-all.sh
```

This will:
- ✅ Deploy all AWS infrastructure (S3 buckets, Lambda, API Gateway, CloudFront)
- ✅ Package and upload Lambda function
- ✅ Upload your template to S3
- ✅ Build and deploy React frontend
- ✅ Show you all the URLs

**Note**: The script will ask for confirmation before applying Terraform changes (type `y` to proceed).

### Customization Options

#### Option 1: Environment Variables (Recommended for one-time deployment)

Before running `deploy-all.sh`, set these in your terminal:

```bash
# Custom project name (affects bucket names)
export PROJECT_NAME="gcloud-proposals"

# Environment (dev, staging, prod)
export ENVIRONMENT="dev"

# AWS Region (eu-west-2 = London, us-east-1 = N. Virginia, etc.)
export AWS_REGION="eu-west-2"

# Run deployment
./scripts/deploy-all.sh
```

**S3 Bucket Names Will Be:**
- Frontend: `gcloud-proposals-dev-frontend`
- Templates: `gcloud-proposals-dev-templates`
- Output: `gcloud-proposals-dev-output`
- Uploads: `gcloud-proposals-dev-uploads`
- Lambda Deploy: `gcloud-proposals-dev-lambda-deploy`

**Frontend URL:**
- S3 Website: `http://gcloud-proposals-dev-frontend.s3-website-eu-west-2.amazonaws.com`
- CloudFront (if enabled): `https://<cloudfront-id>.cloudfront.net`

#### Option 2: Terraform Variables File (Recommended for ongoing deployments)

Create `infrastructure/terraform/aws/terraform.tfvars`:

```hcl
# Project name - used for all resource naming
project_name = "gcloud-proposals"

# Environment (dev, staging, prod)
environment = "dev"

# AWS Region
aws_region = "eu-west-2"  # Options: eu-west-2 (London), eu-west-1 (Ireland), us-east-1 (N. Virginia)

# Application secret key (generate one: openssl rand -base64 32)
app_secret_key = "your-secret-key-here-minimum-32-characters"

# Enable CloudFront CDN (recommended for production)
enable_cloudfront = true

# Lambda deployment package name
lambda_deploy_s3_key = "lambda-package.zip"
```

Then run:
```bash
cd infrastructure/terraform/aws
terraform init
terraform plan   # Review changes
terraform apply  # Apply changes
cd ../../..
./scripts/deploy-all.sh
```

#### Option 3: Command-Line Parameters

```bash
# Set environment variable for project name
export PROJECT_NAME="my-custom-name"

# Run with environment parameter
./scripts/deploy-all.sh prod
```

Or combine both:
```bash
export PROJECT_NAME="my-custom-name"
export AWS_REGION="us-east-1"
./scripts/deploy-all.sh staging
```

## 📋 Step-by-Step Manual Deployment

If you prefer to deploy step-by-step:

### 1. Deploy Infrastructure

```bash
cd infrastructure/terraform/aws

# Create terraform.tfvars (see customization above)
terraform init
terraform plan
terraform apply  # Review and confirm

# Note the outputs (API Gateway URL, bucket names)
terraform output
```

### 2. Deploy Lambda

```bash
# From project root
./scripts/deploy-lambda.sh dev
```

### 3. Upload Template

```bash
# Get template bucket name from Terraform output
TEMPLATE_BUCKET=$(terraform -chdir=infrastructure/terraform/aws output -raw template_bucket)

# Upload template
aws s3 cp docs/service_description_template.docx \
  s3://${TEMPLATE_BUCKET}/templates/service_description_template.docx
```

### 4. Deploy Frontend

```bash
# Get API Gateway URL from Terraform output
API_GATEWAY_URL=$(terraform -chdir=infrastructure/terraform/aws output -raw api_gateway_url)

# Deploy frontend
./scripts/deploy-frontend.sh dev ${API_GATEWAY_URL}
```

## 🎨 Customization Examples

### Example 1: Custom Project Name

```bash
export PROJECT_NAME="pa-gcloud-automation"
export ENVIRONMENT="prod"
./scripts/deploy-all.sh
```

**Result:**
- Buckets: `pa-gcloud-automation-prod-frontend`, etc.
- URL: `http://pa-gcloud-automation-prod-frontend.s3-website-eu-west-2.amazonaws.com`

### Example 2: Different AWS Region

```bash
export PROJECT_NAME="gcloud-automation"
export AWS_REGION="us-east-1"  # N. Virginia (cheaper)
export ENVIRONMENT="dev"
./scripts/deploy-all.sh
```

**Result:**
- Buckets: `gcloud-automation-dev-frontend` (in us-east-1)
- URL: `http://gcloud-automation-dev-frontend.s3-website-us-east-1.amazonaws.com`

### Example 3: Custom Domain (Advanced)

After deployment, you can:
1. Get your CloudFront distribution ID:
```bash
terraform -chdir=infrastructure/terraform/aws output -raw cloudfront_distribution_id
```

2. Point your domain's DNS to CloudFront distribution
3. Request SSL certificate via AWS Certificate Manager
4. Update CloudFront distribution with custom domain

## 🔧 Configuration Files

### Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_NAME` | `gcloud-automation` | Base name for all resources |
| `ENVIRONMENT` | `dev` | Environment (dev/staging/prod) |
| `AWS_REGION` | `eu-west-2` | AWS region for resources |
| `API_GATEWAY_URL` | Auto-detected | API Gateway endpoint URL |

### Terraform Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `gcloud-automation` | Project name for resource naming |
| `environment` | `dev` | Environment name |
| `aws_region` | `eu-west-2` | AWS region |
| `app_secret_key` | *required* | Application secret key (min 32 chars) |
| `enable_cloudfront` | `true` | Enable CloudFront CDN |
| `lambda_deploy_s3_key` | `lambda-package.zip` | Lambda package S3 key |

## 📍 Your URLs After Deployment

After successful deployment, you'll get:

```bash
# Frontend URL
http://<project-name>-<environment>-frontend.s3-website-<region>.amazonaws.com
# OR (if CloudFront enabled)
https://<cloudfront-id>.cloudfront.net

# API Gateway URL
https://<api-id>.execute-api.<region>.amazonaws.com
```

Example output:
```
🔗 Frontend URL:
   https://d1234567890.cloudfront.net

📡 API Gateway URL:
   https://abc123xyz.execute-api.eu-west-2.amazonaws.com
```

## ✅ Prerequisites Checklist

Before running deployment:

- [ ] **AWS CLI configured**: `aws configure` (see [AWS_SETUP.md](AWS_SETUP.md))
- [ ] **AWS credentials verified**: `./scripts/check-aws-setup.sh`
- [ ] **AWS account verified**: `aws sts get-caller-identity`
- [ ] **AWS credentials have permissions** (S3, Lambda, API Gateway, IAM, CloudFront)
- [ ] Terraform installed: `terraform --version`
- [ ] Python 3.12+ installed: `python3 --version`
- [ ] Node.js and npm installed: `node --version && npm --version`
- [ ] Template file exists: `docs/service_description_template.docx`
- [ ] Application secret key generated: `openssl rand -base64 32`

**⚠️ Important:** Run `./scripts/check-aws-setup.sh` first to verify AWS is configured correctly!

## 🛠️ Troubleshooting

### "Bucket name already exists"
S3 bucket names are globally unique. Change `PROJECT_NAME`:
```bash
export PROJECT_NAME="gcloud-automation-$(date +%s)"
```

### "Access Denied"
Check AWS credentials:
```bash
aws sts get-caller-identity
```

### "Template not found"
Ensure template exists:
```bash
ls -la docs/service_description_template.docx
```

### "Terraform state locked"
Another Terraform process is running. Wait or:
```bash
# Only if you're sure no other process is running
terraform force-unlock <lock-id>
```

## 🎯 Quick Commands Reference

```bash
# Check AWS setup (DO THIS FIRST!)
./scripts/check-aws-setup.sh

# Deploy everything (one command)
./scripts/deploy-all.sh

# Deploy just Lambda
./scripts/deploy-lambda.sh dev

# Deploy just frontend
./scripts/deploy-frontend.sh dev <api-gateway-url>

# View Terraform outputs
terraform -chdir=infrastructure/terraform/aws output

# Destroy everything (⚠️ careful! Deletes all resources)
./scripts/destroy-all.sh
```

## 📝 Next Steps

1. **First Deployment**: Run `./scripts/deploy-all.sh` with your custom project name
2. **Get URLs**: Note the frontend and API Gateway URLs from output
3. **Test**: Open frontend URL in browser, create a test proposal
4. **Custom Domain** (optional): Set up custom domain with CloudFront
5. **CI/CD** (optional): Set up GitHub Actions for automatic deployments

## 💡 Pro Tips

- **Use separate environments**: `dev`, `staging`, `prod` with different project names
- **Enable CloudFront for production**: Better performance and HTTPS
- **Use `terraform.tfvars` for teams**: Share configuration without secrets
- **Backup Terraform state**: Consider using S3 backend for Terraform state
- **Monitor costs**: Use AWS Cost Explorer to track spending

