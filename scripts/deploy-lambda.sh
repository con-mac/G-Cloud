#!/bin/bash
# Deploy Lambda function package to S3
# Usage: ./scripts/deploy-lambda.sh [environment]

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${PROJECT_NAME:-gcloud-automation}
AWS_REGION=${AWS_REGION:-eu-west-2}
LAMBDA_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-lambda-deploy"
PACKAGE_NAME="lambda-package.zip"

echo "🚀 Deploying Lambda function to AWS..."
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Bucket: $LAMBDA_BUCKET"

# Navigate to backend directory
cd "$(dirname "$0")/../backend" || exit 1

# Create deployment package directory
rm -rf /tmp/lambda-package
mkdir -p /tmp/lambda-package

# Install dependencies
echo "📦 Installing Python dependencies..."
# Use Lambda-specific requirements if available, otherwise use full requirements
if [ -f "requirements-lambda.txt" ]; then
  echo "✅ Using Lambda-optimized requirements (requirements-lambda.txt)"
  # Lambda uses Python 3.10, need to ensure pydantic-core installs with correct binary
  # First install pydantic-core explicitly with Python 3.10 compatibility (cp310)
  pip install 'pydantic-core>=2.14.1,<2.15.0' -t /tmp/lambda-package --platform manylinux2014_x86_64 --only-binary=:all: --python-version 3.10 --implementation cp --upgrade || \
  pip install 'pydantic-core>=2.14.1,<2.15.0' -t /tmp/lambda-package --platform manylinux2014_x86_64 --only-binary=:all: --upgrade || \
  pip install 'pydantic-core>=2.14.1,<2.15.0' -t /tmp/lambda-package --upgrade
  # Then install other dependencies
  pip install -r requirements-lambda.txt -t /tmp/lambda-package --platform manylinux2014_x86_64 --only-binary=:all: --upgrade || \
  pip install -r requirements-lambda.txt -t /tmp/lambda-package --upgrade
else
  echo "⚠️  Using full requirements.txt (may be large)"
  pip install -r requirements.txt -t /tmp/lambda-package --platform manylinux2014_x86_64 --only-binary=:all: --upgrade || \
  pip install -r requirements.txt -t /tmp/lambda-package --upgrade || \
  pip install -r requirements.txt -t /tmp/lambda-package --no-cache-dir --upgrade
fi

# Copy application code
echo "📋 Copying application code..."
cp -r app /tmp/lambda-package/
# Copy sharepoint_service (needed for S3/local switching)
cp -r sharepoint_service /tmp/lambda-package/

# Create zip package
echo "📦 Creating deployment package..."
cd /tmp/lambda-package

# Check for zip command, use Python if not available
if command -v zip &> /dev/null; then
  zip -r /tmp/${PACKAGE_NAME} . -q
else
  echo "⚠️  zip command not found, using Python to create package..."
  python3 -c "
import os
import zipfile

def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, path)
            ziph.write(file_path, arcname)

with zipfile.ZipFile('/tmp/${PACKAGE_NAME}', 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipdir('.', zipf)
"
fi

# Upload to S3
echo "⬆️  Uploading to S3..."
aws s3 cp /tmp/${PACKAGE_NAME} s3://${LAMBDA_BUCKET}/${PACKAGE_NAME} \
  --region ${AWS_REGION} \
  --metadata "environment=${ENVIRONMENT}"

echo "✅ Lambda package uploaded successfully!"
echo "Package: s3://${LAMBDA_BUCKET}/${PACKAGE_NAME}"

# Cleanup
rm -rf /tmp/lambda-package
rm -f /tmp/${PACKAGE_NAME}

echo "🧹 Cleanup complete"

