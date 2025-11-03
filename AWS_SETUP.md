# AWS Setup Guide

This guide explains how to configure AWS credentials so that Terraform and AWS CLI know which AWS account to use.

## 🔐 AWS Credentials Configuration

When you run deployment scripts, they use the **AWS CLI** and **Terraform**, which need to know:
1. **Which AWS account** to use
2. **What credentials** to use
3. **Which AWS region** to deploy to

## 🚀 Quick Setup

### Step 1: Check Current Setup

```bash
# In Cursor terminal, run:
./scripts/check-aws-setup.sh
```

This will tell you if AWS credentials are configured and show which account you're using.

### Step 2: Configure AWS Credentials

Choose one of these methods:

#### Method 1: AWS CLI Configure (Recommended for Most Users)

This is the easiest method and stores credentials locally:

```bash
# Run AWS configure
aws configure
```

You'll be prompted for:
1. **AWS Access Key ID**: Your AWS access key (get this from AWS Console)
2. **AWS Secret Access Key**: Your AWS secret key (keep this secret!)
3. **Default region**: `eu-west-2` (London) or your preferred region
4. **Default output format**: `json`

**Where to get AWS Access Keys:**

1. Log in to AWS Console: https://console.aws.amazon.com
2. Go to **IAM** → **Users** → Select your user → **Security credentials**
3. Click **Create access key**
4. Choose **Application running outside AWS**
5. Copy the **Access key ID** and **Secret access key** (shown only once!)

**⚠️ Important:** 
- Never commit AWS credentials to Git
- Rotate access keys regularly
- Use least-privilege IAM policies

#### Method 2: Environment Variables (Temporary)

Use this if you want to set credentials for just this session:

```bash
# Set credentials (only for current terminal session)
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_DEFAULT_REGION=eu-west-2

# Verify
aws sts get-caller-identity
```

**Note:** These are lost when you close the terminal.

#### Method 3: AWS Profile (Multiple Accounts)

Use this if you have multiple AWS accounts:

```bash
# Configure a named profile
aws configure --profile my-profile

# Use the profile
export AWS_PROFILE=my-profile

# Or use it in commands
aws s3 ls --profile my-profile
```

#### Method 4: IAM Role (Running on EC2)

If running on an EC2 instance:
- No setup needed! EC2 instances automatically use their IAM role.

## ✅ Verify Your Setup

After configuring, verify it works:

```bash
# Check which account you're using
aws sts get-caller-identity

# This should show:
# {
#   "UserId": "...",
#   "Account": "123456789012",
#   "Arn": "arn:aws:iam::123456789012:user/your-username"
# }

# Or run the check script
./scripts/check-aws-setup.sh
```

## 🔍 Which Account Will Be Used?

The deployment scripts use:
1. **AWS CLI** → Reads from `~/.aws/credentials` (or environment variables)
2. **Terraform** → Uses the same AWS credentials as AWS CLI

**To see which account you're using:**

```bash
# Check current AWS account
aws sts get-caller-identity

# Or check AWS profile
aws configure list
```

## 🗑️ Clean Up All Resources (Important!)

To avoid hidden costs, you can destroy all resources with one command:

### Quick Cleanup

```bash
# Destroy everything (asks for confirmation)
./scripts/destroy-all.sh
```

This will:
- ✅ Delete all S3 buckets (and their contents!)
- ✅ Delete Lambda function
- ✅ Delete API Gateway
- ✅ Delete CloudFront distribution
- ✅ Delete IAM roles and policies
- ✅ Delete all Terraform-managed resources

### Manual Cleanup (If Script Fails)

```bash
# 1. Go to Terraform directory
cd infrastructure/terraform/aws

# 2. Destroy all resources
terraform destroy

# 3. Verify deletion
aws s3 ls | grep <project-name>
aws lambda list-functions | grep <project-name>
aws apigatewayv2 get-apis | grep <project-name>
```

### What Gets Destroyed?

The `destroy-all.sh` script removes:

| Resource | Name Pattern | Notes |
|----------|-------------|-------|
| S3 Buckets | `{project}-{env}-frontend` | ⚠️ **Permanently deletes all files** |
| S3 Buckets | `{project}-{env}-templates` | ⚠️ **Permanently deletes all files** |
| S3 Buckets | `{project}-{env}-output` | ⚠️ **Permanently deletes all files** |
| S3 Buckets | `{project}-{env}-uploads` | ⚠️ **Permanently deletes all files** |
| S3 Buckets | `{project}-{env}-lambda-deploy` | ⚠️ **Permanently deletes all files** |
| Lambda Function | `{project}-{env}-api` | All code and configuration |
| API Gateway | `{project}-{env}-api` | All routes and integrations |
| CloudFront | Auto-generated ID | Distribution and cache |
| IAM Roles | `{project}-{env}-lambda-role` | Lambda execution role |
| CloudWatch Logs | `/aws/lambda/{project}-{env}-api` | Lambda logs |

### Cost Monitoring

**Monitor AWS Costs:**

```bash
# Check current costs (requires AWS CLI with appropriate permissions)
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

**Or use AWS Console:**
1. Go to **AWS Cost Management** → **Cost Explorer**
2. Filter by service (Lambda, S3, API Gateway, CloudFront)
3. Set up cost alerts for budgets

**Estimated Monthly Costs (Low Traffic):**
- Lambda: ~£0.20 per million requests (first 1M free)
- API Gateway: ~£2.50 per million requests (first 1M free)
- S3 Storage: ~£0.023 per GB (first 5GB free)
- S3 Requests: ~£0.004 per 1,000 requests
- CloudFront: ~£0.06 per GB (first 1TB free)

**Total:** ~£5-10/month for low-traffic development environment

## 🔒 Security Best Practices

1. **Never commit credentials**:
   - ✅ Use `.gitignore` to exclude `~/.aws/credentials`
   - ✅ Don't commit `terraform.tfvars` with secrets

2. **Use IAM roles with least privilege**:
   - Only grant permissions needed for deployment
   - Use separate accounts for dev/staging/prod

3. **Rotate credentials regularly**:
   - Change access keys every 90 days
   - Use AWS Secrets Manager for applications

4. **Enable MFA** for production accounts

5. **Use AWS Organizations** for multi-account setups

## 📋 Required IAM Permissions

Your AWS user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "lambda:*",
        "apigateway:*",
        "cloudfront:*",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:CreatePolicy",
        "iam:DeleteRole",
        "iam:DeletePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:GetRole",
        "iam:PassRole",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

**Or use AWS managed policies:**
- `AdministratorAccess` (full access - use with caution)
- `PowerUserAccess` (most services, no IAM management)

## 🛠️ Troubleshooting

### "Unable to locate credentials"

```bash
# Check if credentials are set
aws configure list

# Re-configure
aws configure
```

### "Access Denied" or "Forbidden"

```bash
# Check your permissions
aws sts get-caller-identity

# Verify IAM policies
aws iam list-attached-user-policies --user-name your-username
```

### Wrong AWS Account

```bash
# Check current account
aws sts get-caller-identity

# Switch profile
export AWS_PROFILE=correct-profile

# Re-verify
aws sts get-caller-identity
```

### Terraform State Lock

If Terraform says state is locked:

```bash
# Only if you're sure no other process is running
cd infrastructure/terraform/aws
terraform force-unlock <lock-id>
```

## 📚 Additional Resources

- **AWS CLI Documentation**: https://docs.aws.amazon.com/cli/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **AWS IAM Best Practices**: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- **AWS Cost Management**: https://aws.amazon.com/aws-cost-management/

## 🎯 Quick Reference

```bash
# 1. Configure AWS credentials
aws configure

# 2. Verify setup
./scripts/check-aws-setup.sh

# 3. Deploy everything
./scripts/deploy-all.sh

# 4. Check costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY

# 5. Destroy everything (cleanup)
./scripts/destroy-all.sh
```

