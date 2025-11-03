#!/bin/bash
# Deploy frontend to S3
# Usage: ./scripts/deploy-frontend.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}
FRONTEND_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-frontend"
API_GATEWAY_URL=${API_GATEWAY_URL:-""}

echo "🚀 Deploying frontend to S3..."
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Bucket: $FRONTEND_BUCKET"

# Navigate to frontend directory
cd "$(dirname "$0")/../frontend" || exit 1

# Build frontend
echo "🏗️  Building frontend..."
if [ -n "$API_GATEWAY_URL" ]; then
  echo "Setting API endpoint to: $API_GATEWAY_URL"
  VITE_API_BASE_URL=$API_GATEWAY_URL npm run build
else
  npm run build
fi

# Upload to S3
echo "⬆️  Uploading to S3..."
aws s3 sync dist/ s3://${FRONTEND_BUCKET}/ \
  --region ${AWS_REGION} \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "*.html" \
  --metadata "environment=${ENVIRONMENT}"

# Upload HTML files with no-cache
aws s3 sync dist/ s3://${FRONTEND_BUCKET}/ \
  --region ${AWS_REGION} \
  --delete \
  --cache-control "no-cache, no-store, must-revalidate" \
  --include "*.html" \
  --metadata "environment=${ENVIRONMENT}"

echo "✅ Frontend deployed successfully!"
echo "Website URL: http://${FRONTEND_BUCKET}.s3-website-${AWS_REGION}.amazonaws.com"

