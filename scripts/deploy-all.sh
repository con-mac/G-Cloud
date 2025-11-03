#!/bin/bash
# Complete deployment script: Infrastructure -> Lambda -> Frontend -> Templates
# Usage: ./scripts/deploy-all.sh [environment] [api-gateway-url]
#
# Customization via environment variables:
#   PROJECT_NAME - Project name (default: gcloud-automation)
#   AWS_REGION   - AWS region (default: eu-west-2)
#   ENVIRONMENT  - Environment name (default: dev)
#
# Or use terraform.tfvars in infrastructure/terraform/aws/

set -e

ENVIRONMENT=${1:-${ENVIRONMENT:-dev}}
API_GATEWAY_URL=${2:-""}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}
TEMPLATE_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-templates"

echo "🚀 Starting complete deployment..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuration:"
echo "  Project Name: $PROJECT_NAME"
echo "  Environment:  $ENVIRONMENT"
echo "  AWS Region:   $AWS_REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Deploy infrastructure with Terraform
echo ""
echo "📐 Step 1: Deploying infrastructure with Terraform..."
echo ""
cd infrastructure/terraform/aws || exit 1

# Check if terraform.tfvars exists (for custom configuration)
TFVARS_FILE="terraform.tfvars"
if [ -f "$TFVARS_FILE" ]; then
  echo "✅ Found $TFVARS_FILE - using custom configuration"
  terraform init
  terraform plan
else
  echo "📝 Using environment variables (create $TFVARS_FILE for permanent config)"
  terraform init
  terraform plan \
    -var="environment=${ENVIRONMENT}" \
    -var="aws_region=${AWS_REGION}" \
    -var="project_name=${PROJECT_NAME}"
fi

echo ""
read -p "Apply these changes? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if [ -f "$TFVARS_FILE" ]; then
    terraform apply -auto-approve
  else
    terraform apply \
      -var="environment=${ENVIRONMENT}" \
      -var="aws_region=${AWS_REGION}" \
      -var="project_name=${PROJECT_NAME}" \
      -auto-approve
  fi
else
  echo "❌ Terraform apply cancelled"
  exit 1
fi

# Get API Gateway URL from Terraform output if not provided
if [ -z "$API_GATEWAY_URL" ]; then
  API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
  echo "📡 API Gateway URL: $API_GATEWAY_URL"
fi

cd - || exit 1

# Step 2: Package and deploy Lambda
echo ""
echo "📦 Step 2: Packaging and deploying Lambda function..."
./scripts/deploy-lambda.sh ${ENVIRONMENT}

# Step 3: Upload template to S3
echo ""
echo "📄 Step 3: Uploading template to S3..."
if [ -f "docs/service_description_template.docx" ]; then
  aws s3 cp docs/service_description_template.docx \
    s3://${TEMPLATE_BUCKET}/templates/service_description_template.docx \
    --region ${AWS_REGION}
  echo "✅ Template uploaded"
else
  echo "⚠️  Template not found at docs/service_description_template.docx"
  echo "   Upload it manually: aws s3 cp <template> s3://${TEMPLATE_BUCKET}/templates/service_description_template.docx"
fi

# Step 4: Deploy frontend
echo ""
echo "🌐 Step 4: Deploying frontend..."
./scripts/deploy-frontend.sh ${ENVIRONMENT} ${API_GATEWAY_URL}

# Step 5: Get frontend URL
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Deployment Summary:"
cd infrastructure/terraform/aws || exit 1
terraform output
cd - || exit 1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔗 Your URLs:"
echo ""

FRONTEND_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-frontend"

# Get frontend URL
FRONTEND_URL=$(terraform -chdir=infrastructure/terraform/aws output -raw frontend_url 2>/dev/null || echo "")
if [ -n "$FRONTEND_URL" ] && echo "$FRONTEND_URL" | grep -q "cloudfront.net"; then
  echo "   Frontend (CloudFront): https://$FRONTEND_URL"
else
  echo "   Frontend (S3):         http://${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"
fi

# Get API Gateway URL
API_URL=$(terraform -chdir=infrastructure/terraform/aws output -raw api_gateway_url 2>/dev/null || echo "")
if [ -n "$API_URL" ]; then
  echo "   API Gateway:           $API_URL"
fi

echo ""
echo "📦 S3 Buckets Created:"
echo "   - ${PROJECT_NAME}-${ENVIRONMENT}-frontend"
echo "   - ${PROJECT_NAME}-${ENVIRONMENT}-templates"
echo "   - ${PROJECT_NAME}-${ENVIRONMENT}-output"
echo "   - ${PROJECT_NAME}-${ENVIRONMENT}-uploads"
echo ""
echo "💡 To customize bucket names, set PROJECT_NAME environment variable"
echo "   Example: export PROJECT_NAME='my-custom-name'"
echo ""
echo "📚 For more customization options, see:"
echo "   - QUICK_DEPLOY.md (quick setup guide)"
echo "   - infrastructure/terraform/aws/terraform.tfvars (permanent config)"
echo ""

