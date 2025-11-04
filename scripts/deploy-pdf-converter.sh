#!/bin/bash
# Deploy PDF Converter Lambda container image to ECR
# Usage: ./scripts/deploy-pdf-converter.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}
ECR_REPO="${PROJECT_NAME}-${ENVIRONMENT}-pdf-converter"

echo "🚀 Building and deploying PDF Converter Lambda container..."
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "ECR Repository: $ECR_REPO"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region ${AWS_REGION})
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

# Navigate to PDF converter directory
cd "$(dirname "$0")/../backend/pdf_converter" || exit 1

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Build Docker image for Lambda (linux/amd64 platform)
# Using multi-stage build to get LibreOffice from Shelf base image
# Lambda requires OCI format, so we use docker buildx with proper output
echo "🏗️  Building Docker image for Lambda (linux/amd64) with LibreOffice..."
export DOCKER_BUILDKIT=1

# Build and push using buildx for Lambda-compatible format
docker buildx build --platform linux/amd64 \
    --output type=docker \
    -t ${ECR_REPO}:latest \
    -t ${ECR_URI}:latest \
    .

# Push to ECR (Lambda requires OCI/Docker v2 manifest)
echo "⬆️  Pushing image to ECR..."
docker push ${ECR_URI}:latest

# Update Lambda function
echo "🔄 Updating Lambda function..."
aws lambda update-function-code \
  --function-name ${PROJECT_NAME}-${ENVIRONMENT}-pdf-converter \
  --image-uri ${ECR_URI}:latest \
  --region ${AWS_REGION}

echo "✅ PDF Converter Lambda deployed successfully!"
echo "Image URI: ${ECR_URI}:latest"

