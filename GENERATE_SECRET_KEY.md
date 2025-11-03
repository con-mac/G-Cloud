# Generating Application Secret Key

## What is the Application Secret Key?

The application secret key is a **secure random string** used by your application for:
- Encrypting session cookies
- Signing CSRF tokens
- Other cryptographic operations

**⚠️ Important:** This is NOT from AWS - you generate it yourself!

## How to Generate

### Option 1: Using OpenSSL (Recommended)

```bash
openssl rand -base64 32
```

This will output something like:
```
dGhpc2lzYXJhbmRvbXNlY3JldGtleWZvcnNlc3Npb25z
```

**Copy this entire string** - you'll need it for your `terraform.tfvars` file.

### Option 2: Using Python

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Option 3: Using Node.js

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

### Option 4: Online Generator (Less Secure)

You can use an online generator, but it's less secure:
- https://www.random.org/strings/
- Generate 32 characters, use alphanumeric

**⚠️ Security Note:** Don't share this key or commit it to Git!

## Using the Secret Key

### Step 1: Generate the Key

```bash
# Run this command:
openssl rand -base64 32
```

Example output:
```
kL9mN4pQ7rT2vW8xY3zA6bC1dE5fG9hI0jK2lM4n
```

### Step 2: Add to terraform.tfvars

Create or edit `infrastructure/terraform/aws/terraform.tfvars`:

```hcl
project_name    = "gcloud-automation"
environment     = "dev"
aws_region      = "eu-west-2"
app_secret_key  = "kL9mN4pQ7rT2vW8xY3zA6bC1dE5fG9hI0jK2lM4n"  # Your generated key here
enable_cloudfront = true
lambda_deploy_s3_key = "lambda-package.zip"
```

### Step 3: Deploy

Now you can deploy:

```bash
./scripts/deploy-all.sh
```

The Terraform script will automatically use the key from `terraform.tfvars`.

## Requirements

- **Minimum length:** 32 characters (but longer is better)
- **Format:** Base64-encoded string works best
- **Uniqueness:** Generate a unique key for each environment (dev, staging, prod)

## Different Keys for Different Environments

**Best Practice:** Use different secret keys for each environment:

```bash
# Generate separate keys:
openssl rand -base64 32 > dev-key.txt
openssl rand -base64 32 > staging-key.txt
openssl rand -base64 32 > prod-key.txt
```

Then use:
- `terraform.tfvars.dev` → dev key
- `terraform.tfvars.staging` → staging key
- `terraform.tfvars.prod` → prod key

## Security Best Practices

1. **Never commit secret keys to Git** ✅ (Already in `.gitignore`)
2. **Don't share keys** - Each environment should have its own
3. **Rotate keys regularly** - Change them every 90 days
4. **Store securely** - Use AWS Secrets Manager or similar for production
5. **Use different keys** - Never reuse the same key across environments

## Troubleshooting

### "Secret key too short"

Make sure your key is at least 32 characters. Generate a longer one:

```bash
openssl rand -base64 48  # Longer key (48 characters)
```

### "Invalid format"

Make sure you're copying the entire output from the generator command. No spaces, no extra characters.

### "Secret key not found"

Make sure you've added it to `terraform.tfvars` and the file is in the correct location:
```
infrastructure/terraform/aws/terraform.tfvars
```

## Quick Reference

```bash
# 1. Generate key
openssl rand -base64 32

# 2. Add to terraform.tfvars (don't forget quotes!)
app_secret_key = "your-generated-key-here"

# 3. Deploy
./scripts/deploy-all.sh
```

---

**That's it!** The secret key is just a random string you generate yourself. No AWS account needed for this step.

