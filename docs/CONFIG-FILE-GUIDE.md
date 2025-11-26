# Configuration File Management Guide

## Overview

The `config/deployment-config.env` file stores all deployment configuration values. This guide explains how the dev team should handle this file.

## How It Works

### Initial Deployment

1. **First Time Setup**: When you run `.\deploy.ps1` for the first time, it will:
   - Prompt you for all configuration values interactively
   - Create `config/deployment-config.env` with your answers
   - Use this file for all subsequent deployment steps

2. **Subsequent Deployments**: The script reads from `config/deployment-config.env` to:
   - Know which resources to use (existing vs. new)
   - Deploy to the correct Function App and Web App
   - Configure the right Key Vault, Storage Account, etc.

### File Location

```
pa-deployment/
└── config/
    ├── deployment-config.env          # ⚠️ DO NOT COMMIT (contains your specific values)
    └── deployment-config.env.template # ✅ Safe to commit (template only)
```

## Best Practices for Dev Team

### ✅ DO

1. **Keep the file local**: `deployment-config.env` is in `.gitignore` - never commit it
2. **Use the template**: Reference `deployment-config.env.template` to see what values are needed
3. **Backup before changes**: The script creates backups automatically, but you can also:
   ```powershell
   Copy-Item config\deployment-config.env config\deployment-config.env.backup
   ```
4. **Fix corrupted files**: If values get truncated or corrupted, use:
   ```powershell
   .\scripts\fix-config.ps1
   ```
5. **Recreate if needed**: If the file is lost, just run `.\deploy.ps1` again - it will recreate it

### ❌ DON'T

1. **Don't commit it**: The file contains environment-specific values
2. **Don't share it**: Contains resource names and IDs specific to your deployment
3. **Don't edit manually unless necessary**: The deployment script manages it
4. **Don't delete it**: Other scripts depend on it (but you can recreate it)

## Workflow Scenarios

### Scenario 1: First Deployment

```powershell
# 1. Run the main deployment script
.\deploy.ps1

# 2. Answer all prompts (Resource Group, Function App, Web App, etc.)
# 3. Script creates config/deployment-config.env automatically
# 4. Script uses this config for all subsequent steps
```

### Scenario 2: Redeploying to Same Environment

```powershell
# 1. Config file already exists from previous deployment
# 2. Run deploy.ps1 again
.\deploy.ps1

# 3. Script will:
#    - Read existing config
#    - Ask if you want to use existing resources or create new
#    - Update config file if you make changes
```

### Scenario 3: Deploying to Different Environment

```powershell
# Option A: Use different config file
# 1. Backup current config
Copy-Item config\deployment-config.env config\deployment-config.env.prod

# 2. Run deploy.ps1 - it will prompt for new values
.\deploy.ps1

# Option B: Manual edit (not recommended)
# 1. Edit config/deployment-config.env manually
# 2. Run individual scripts:
.\scripts\setup-resources.ps1
.\scripts\deploy-functions.ps1
.\scripts\deploy-frontend.ps1
```

### Scenario 4: Config File Corrupted or Lost

```powershell
# Option A: Use fix script
.\scripts\fix-config.ps1

# Option B: Recreate from scratch
# 1. Delete corrupted file
Remove-Item config\deployment-config.env

# 2. Run deploy.ps1 - it will recreate it
.\deploy.ps1
```

## Config File Structure

The `deployment-config.env` file contains:

```env
# Resource Configuration
RESOURCE_GROUP=pa-gcloud15-rg
LOCATION=uksouth
SUBSCRIPTION_ID=your-subscription-id

# Application Names
FUNCTION_APP_NAME=pa-gcloud15-api
WEB_APP_NAME=pa-gcloud15-web
KEY_VAULT_NAME=pa-gcloud15-kv

# SharePoint Configuration
SHAREPOINT_SITE_URL=https://paconsulting.sharepoint.com/sites/GCloud15
SHAREPOINT_SITE_ID=site-id-here

# App Registration
APP_REGISTRATION_NAME=pa-gcloud15-app

# Resource Choices (existing/new/skip)
STORAGE_ACCOUNT_CHOICE=existing
STORAGE_ACCOUNT_NAME=your-storage-account
PRIVATE_DNS_CHOICE=new
PRIVATE_DNS_ZONE_NAME=privatelink.azurewebsites.net
APP_INSIGHTS_CHOICE=existing
APP_INSIGHTS_NAME=pa-gcloud15-api-insights

# VNet Configuration
CONFIGURE_PRIVATE_ENDPOINTS=true
VNET_NAME=pa-gcloud15-vnet
SUBNET_NAME=functions-subnet
```

## Team Collaboration

### For Multiple Team Members

1. **Each team member** should have their own `deployment-config.env` file
2. **Don't share** the actual config file (it's gitignored for a reason)
3. **Share the template** (`deployment-config.env.template`) if you need to document required values
4. **Coordinate resource names** if deploying to the same Azure subscription

### For Different Environments

- **Dev Environment**: `deployment-config.env.dev` (not committed)
- **Staging Environment**: `deployment-config.env.staging` (not committed)
- **Production Environment**: `deployment-config.env.prod` (not committed)

You can manage multiple configs by:
```powershell
# Switch between environments
Copy-Item config\deployment-config.env.dev config\deployment-config.env
.\deploy.ps1
```

## Troubleshooting

### Config File Not Found

```powershell
# Error: "deployment-config.env not found"
# Solution: Run deploy.ps1 to create it
.\deploy.ps1
```

### Values Are Truncated

```powershell
# Error: FUNCTION_APP_NAME shows as "p" instead of full name
# Solution: Use fix script
.\scripts\fix-config.ps1
```

### Wrong Resource Group

```powershell
# Check current value
Get-Content config\deployment-config.env | Select-String "RESOURCE_GROUP"

# Fix it
.\scripts\fix-config.ps1
# Or manually edit and ensure it ends with "-rg"
```

### Need to Update a Value

```powershell
# Option 1: Re-run deploy.ps1 and answer prompts differently
.\deploy.ps1

# Option 2: Edit manually (be careful with formatting)
notepad config\deployment-config.env
```

## Security Notes

- ⚠️ **Never commit** `deployment-config.env` to git
- ⚠️ **Contains resource names** that could reveal infrastructure details
- ⚠️ **SharePoint URLs** may contain sensitive information
- ✅ **Template file** is safe to commit (no real values)

## Summary

| Action | Method | When to Use |
|--------|--------|-------------|
| Create config | Run `.\deploy.ps1` | First deployment |
| Update config | Run `.\deploy.ps1` | Changing resources |
| Fix corrupted | Run `.\scripts\fix-config.ps1` | Values truncated |
| View config | `Get-Content config\deployment-config.env` | Check current values |
| Backup config | `Copy-Item config\deployment-config.env config\deployment-config.env.backup` | Before major changes |

## Questions?

If you're unsure about how to handle the config file:
1. Check this guide first
2. Use `.\scripts\fix-config.ps1` if values look wrong
3. Re-run `.\deploy.ps1` to recreate it if needed
4. The script is designed to be idempotent - safe to run multiple times

