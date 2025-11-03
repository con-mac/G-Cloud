#!/bin/bash
# Check AWS credentials and configuration
# Usage: ./scripts/check-aws-setup.sh

set -e

echo "🔍 Checking AWS Configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI is not installed"
  echo ""
  echo "Install AWS CLI:"
  echo "  https://aws.amazon.com/cli/"
  echo ""
  exit 1
fi

echo "✅ AWS CLI is installed: $(aws --version)"
echo ""

# Check AWS credentials
echo "📋 Checking AWS Credentials..."
echo ""

if aws sts get-caller-identity &> /dev/null; then
  echo "✅ AWS credentials are configured"
  echo ""
  
  # Get current AWS account info
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
  AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
  AWS_REGION=$(aws configure get region || echo "not set")
  
  echo "   Account ID: $AWS_ACCOUNT_ID"
  echo "   User/Role:  $AWS_USER_ARN"
  echo "   Region:     ${AWS_REGION:-not set (using eu-west-2 default)}"
  echo ""
  
  # Check AWS profile if set
  AWS_PROFILE=$(aws configure get profile.default 2>/dev/null || echo "")
  if [ -n "$AWS_PROFILE" ] || [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE=${AWS_PROFILE:-default}
    echo "   Profile:    $AWS_PROFILE"
    echo ""
  fi
  
else
  echo "❌ AWS credentials are NOT configured"
  echo ""
  echo "Setup AWS credentials using one of these methods:"
  echo ""
  echo "1. AWS CLI Configure (Recommended):"
  echo "   aws configure"
  echo "   # You'll need:"
  echo "   #   - AWS Access Key ID"
  echo "   #   - AWS Secret Access Key"
  echo "   #   - Default region (e.g., eu-west-2)"
  echo "   #   - Default output format (json)"
  echo ""
  echo "2. Environment Variables:"
  echo "   export AWS_ACCESS_KEY_ID=your-access-key"
  echo "   export AWS_SECRET_ACCESS_KEY=your-secret-key"
  echo "   export AWS_DEFAULT_REGION=eu-west-2"
  echo ""
  echo "3. AWS Profile:"
  echo "   export AWS_PROFILE=your-profile-name"
  echo ""
  echo "4. IAM Role (if running on EC2):"
  echo "   # No setup needed - uses instance role automatically"
  echo ""
  exit 1
fi

# Check Terraform
echo "📋 Checking Terraform..."
echo ""

if command -v terraform &> /dev/null; then
  echo "✅ Terraform is installed: $(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"
else
  echo "❌ Terraform is not installed"
  echo ""
  echo "Install Terraform:"
  echo "  https://www.terraform.io/downloads"
  echo ""
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All checks passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "You're ready to deploy! Run:"
echo "  ./scripts/deploy-all.sh"
echo ""

