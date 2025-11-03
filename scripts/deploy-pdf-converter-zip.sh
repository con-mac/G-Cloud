#!/bin/bash
# Deploy PDF Converter Lambda as ZIP package
# Usage: ./scripts/deploy-pdf-converter-zip.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}
LAMBDA_DEPLOY_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-lambda-deploy"

echo "🚀 Building and deploying PDF Converter Lambda (ZIP package)..."
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Deploy Bucket: $LAMBDA_DEPLOY_BUCKET"

# Navigate to PDF converter directory
cd "$(dirname "$0")/../backend/pdf_converter" || exit 1

# Create temporary directory for package
TMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TMP_DIR/pdf-converter-package"

echo "📦 Creating deployment package..."
mkdir -p "$PACKAGE_DIR"

# Install dependencies
echo "📥 Installing Python dependencies..."
pip install -r requirements.txt --target "$PACKAGE_DIR" --platform manylinux2014_x86_64 --implementation cp --python-version 3.10 --only-binary=:all: --no-deps || \
pip install -r requirements.txt --target "$PACKAGE_DIR" --platform manylinux2014_x86_64 --implementation cp --python-version 3.10 --no-deps

# Copy function code
echo "📋 Copying function code..."
cp pdf_converter.py "$PACKAGE_DIR/"

# Create ZIP file
cd "$PACKAGE_DIR"
ZIP_FILE="$TMP_DIR/pdf-converter.zip"

if command -v zip &> /dev/null; then
    zip -r "$ZIP_FILE" . -q
else
    echo "⚠️  zip command not found, using Python to create package..."
    python3 -c "
import zipfile
import os
import sys

with zipfile.ZipFile('$ZIP_FILE', 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk('.'):
        for file in files:
            filepath = os.path.join(root, file)
            arcname = os.path.relpath(filepath, '.')
            zipf.write(filepath, arcname)
"
fi

# Upload to S3
echo "⬆️  Uploading to S3..."
aws s3 cp "$ZIP_FILE" "s3://${LAMBDA_DEPLOY_BUCKET}/pdf-converter.zip" --region "${AWS_REGION}"

# Update Lambda function code
echo "🔄 Updating Lambda function..."
aws lambda update-function-code \
  --function-name "${PROJECT_NAME}-${ENVIRONMENT}-pdf-converter" \
  --s3-bucket "${LAMBDA_DEPLOY_BUCKET}" \
  --s3-key "pdf-converter.zip" \
  --region "${AWS_REGION}" \
  --query 'LastUpdateStatus' \
  --output text

# Cleanup
rm -rf "$TMP_DIR"

echo "✅ PDF Converter Lambda deployed successfully!"
echo "Package: s3://${LAMBDA_DEPLOY_BUCKET}/pdf-converter.zip"

