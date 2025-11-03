#!/bin/bash
# Destroy all AWS resources created by Terraform
# Usage: ./scripts/destroy-all.sh [environment]
#
# WARNING: This will delete ALL resources including S3 buckets and their contents!
# Ensure you have backups if needed.

set -e

ENVIRONMENT=${1:-${ENVIRONMENT:-dev}}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}

echo "⚠️  WARNING: This will DESTROY all AWS resources!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project Name: $PROJECT_NAME"
echo "Environment:  $ENVIRONMENT"
echo "AWS Region:   $AWS_REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This will delete:"
echo "  ❌ All S3 buckets (frontend, templates, output, uploads, lambda-deploy)"
echo "  ❌ Lambda function"
echo "  ❌ API Gateway"
echo "  ❌ CloudFront distribution (if enabled)"
echo "  ❌ IAM roles and policies"
echo "  ❌ CloudWatch log groups"
echo ""
echo "⚠️  S3 buckets and their contents will be PERMANENTLY DELETED!"
echo ""

# Check if terraform.tfvars exists
cd infrastructure/terraform/aws || exit 1
TFVARS_FILE="terraform.tfvars"

if [ -f "$TFVARS_FILE" ]; then
  echo "✅ Found $TFVARS_FILE - will use this configuration"
  TERRAFORM_VARS=""
else
  echo "📝 Using environment variables"
  TERRAFORM_VARS="-var=\"environment=${ENVIRONMENT}\" -var=\"aws_region=${AWS_REGION}\" -var=\"project_name=${PROJECT_NAME}\""
fi

# Show what will be destroyed
echo ""
echo "📋 Resources that will be destroyed:"
echo ""
terraform init -upgrade > /dev/null 2>&1

if [ -f "$TFVARS_FILE" ]; then
  terraform plan -destroy
else
  eval "terraform plan -destroy $TERRAFORM_VARS"
fi

echo ""
read -p "⚠️  Are you ABSOLUTELY SURE you want to destroy everything? Type 'yes' to confirm: " -r
echo

if [[ ! $REPLY == "yes" ]]; then
  echo "❌ Destruction cancelled"
  exit 1
fi

echo ""
echo "🗑️  Destroying all resources..."
echo ""

# Destroy Terraform-managed resources
if [ -f "$TFVARS_FILE" ]; then
  terraform destroy -auto-approve
else
  eval "terraform destroy -auto-approve $TERRAFORM_VARS"
fi

cd - || exit 1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Destruction Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All AWS resources have been destroyed."
echo ""
echo "💡 Note: Some resources may take a few minutes to fully delete:"
echo "   - CloudFront distributions can take up to 15 minutes"
echo "   - S3 buckets may show up for a few minutes after deletion"
echo ""
echo "🔍 Verify deletion:"
echo "   aws s3 ls | grep ${PROJECT_NAME}-${ENVIRONMENT}"
echo "   aws lambda list-functions | grep ${PROJECT_NAME}-${ENVIRONMENT}"
echo "   aws apigatewayv2 get-apis | grep ${PROJECT_NAME}-${ENVIRONMENT}"
echo ""

