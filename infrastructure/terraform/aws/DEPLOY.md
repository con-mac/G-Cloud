# Quick Deploy Guide

## Yes, this uses the same AWS account and setup!

The new infrastructure **adds** a SharePoint S3 bucket to your existing setup. It doesn't change or remove anything that's already deployed.

## Quick Deploy Steps

### 1. Navigate to Terraform Directory
```bash
cd /home/con-mac/dev/projects/gcloud_automate/infrastructure/terraform/aws
```

### 2. Check Your Existing Configuration
```bash
# View your current terraform.tfvars (if it exists)
cat terraform.tfvars

# Or check what variables are set
terraform console
```

### 3. Initialize Terraform (if needed)
```bash
terraform init
```

### 4. Review Changes
```bash
# See what will be added (should only show the new SharePoint bucket)
terraform plan
```

You should see something like:
```
Plan: 2 to add, 0 to change, 0 to destroy.

  # aws_s3_bucket.sharepoint will be created
  # aws_s3_bucket_versioning.sharepoint will be created
```

### 5. Apply Changes
```bash
terraform apply
```

When prompted, type `yes` to confirm.

### 6. Get the SharePoint Bucket Name
```bash
# After apply completes, get the bucket name
terraform output sharepoint_bucket
```

### 7. Upload Your Local SharePoint Data to S3
```bash
# IMPORTANT: Make sure you're in the terraform directory first!
# Get the bucket name from Terraform output (must be run from terraform directory)
cd /home/con-mac/dev/projects/gcloud_automate/infrastructure/terraform/aws
SHAREPOINT_BUCKET=$(terraform output -raw sharepoint_bucket)

# Now navigate to project root and upload
cd /home/con-mac/dev/projects/gcloud_automate
aws s3 sync mock_sharepoint/ s3://$SHAREPOINT_BUCKET/ --exclude "*.git/*"
```

### 8. Update Lambda Environment Variables
The Lambda function should already have `SHAREPOINT_BUCKET_NAME` set from Terraform, but verify:

```bash
# Check Lambda environment variables
aws lambda get-function-configuration --function-name gcloud-automation-dev-api --query 'Environment.Variables.SHAREPOINT_BUCKET_NAME'
```

If it's not set, you can update it:
```bash
# Get the bucket name
SHAREPOINT_BUCKET=$(terraform output -raw sharepoint_bucket)

# Update Lambda environment variable
aws lambda update-function-configuration \
  --function-name gcloud-automation-dev-api \
  --environment "Variables={USE_S3=true,SHAREPOINT_BUCKET_NAME=$SHAREPOINT_BUCKET,...}"
```

**Note**: Terraform should have already set this, so this step is usually not needed.

## What Gets Added

- ✅ New S3 bucket: `gcloud-automation-dev-sharepoint`
- ✅ S3 bucket versioning (enabled)
- ✅ IAM permissions for Lambda to access the SharePoint bucket
- ✅ Environment variable `SHAREPOINT_BUCKET_NAME` in Lambda

## What Stays the Same

- ✅ All existing S3 buckets (frontend, templates, output, uploads)
- ✅ All existing Lambda functions
- ✅ All existing API Gateway endpoints
- ✅ All existing CloudFront distributions
- ✅ All existing IAM roles and policies (just updated, not replaced)

## Troubleshooting

### If terraform plan shows changes to existing resources:
This shouldn't happen, but if it does, review the changes carefully. The new infrastructure only adds resources, it doesn't modify existing ones.

### If you get "bucket already exists" error:
The bucket name might already exist. Terraform will handle this, but if you see an error, check:
```bash
aws s3 ls | grep sharepoint
```

### If Lambda can't access S3:
Check IAM role permissions:
```bash
aws iam get-role-policy --role-name gcloud-automation-dev-lambda-role --policy-name gcloud-automation-dev-lambda-s3-policy
```

## After Deployment

Your system will now:
- Use S3 for SharePoint storage when `USE_S3=true` (in Lambda)
- Use local files when `USE_S3=false` (local development)

The Lambda function already has `USE_S3=true` set, so it will automatically use S3 after you upload the data.

