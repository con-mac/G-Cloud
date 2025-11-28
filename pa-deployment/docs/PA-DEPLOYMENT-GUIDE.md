# PA Environment Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the G-Cloud 15 automation tool to PA Consulting's Azure dev environment. The deployment is **iterative** - you can run it multiple times safely, and configure private endpoints now or later.

## Prerequisites

- Azure CLI installed and configured
- Access to PA's Azure subscription
- Access to SharePoint site
- App Registration permissions in Azure AD
- VNet and private endpoint access (if required)

## Quick Start

### For Fresh Deployment (Recommended)

1. **Clean up existing resources** (if any):
   ```powershell
   .\scripts\cleanup-resources.ps1
   ```
   This will delete all resources in the resource group (App Registration persists).

2. **Run the deployment script**:
   ```powershell
   .\deploy.ps1
   ```
3. **Follow the interactive prompts** to configure resources
4. **Complete SharePoint integration** (see SharePoint Integration section)

### For Iterative Deployment

If you already have resources deployed and want to update them:
```powershell
.\deploy.ps1
```
The script will detect existing resources and let you reuse or recreate them.

## Deployment Steps

### Step 1: Initial Configuration

Run the main deployment script:
```powershell
.\deploy.ps1
```

This will:
- Check prerequisites (Azure CLI, login status)
- Prompt for resource names (or use existing)
- Ask if you want private endpoints now (y) or later (n)
- Save configuration to `config/deployment-config.env`
- Run all deployment steps automatically

**Private Endpoints**: 
- Choose **y** for production (private-only access)
- Choose **n** for testing (allows public access, can add private endpoints later)

**Config File**: Created automatically at `config/deployment-config.env`. You can run `.\deploy.ps1` again anytime - it will use existing config and let you update it.

### Step 2: Resource Setup

The script automatically runs `scripts/setup-resources.sh` which creates:
- Resource Group
- Storage Account (for temp files)
- Key Vault
- Function App (backend API)
- Web App (frontend)
- Application Insights

### Step 3: Backend Deployment

The script runs `scripts/deploy-functions.sh` which:
- Packages backend code
- Deploys to Function App
- Configures app settings
- Sets up Key Vault references

### Step 4: Frontend Deployment

The script runs `scripts/deploy-frontend.sh` which:
- Builds React frontend
- Configures API endpoints
- Deploys to Web App

### Step 5: Authentication Configuration

The script runs `scripts/configure-auth.sh` which:
- Creates/updates App Registration
- Configures Microsoft 365 SSO
- Stores credentials in Key Vault
- Updates app settings

## SharePoint Integration

### Current Status

**PLACEHOLDER**: SharePoint integration is not yet implemented. The code includes placeholder functions that need to be completed.

### Required Implementation

1. **Complete `sharepoint_service/sharepoint_online.py`**:
   - Implement Graph API client initialization
   - Implement file upload/download
   - Implement folder creation
   - Implement document search

2. **Update `document_generator.py`**:
   - Replace Azure Blob Storage calls with SharePoint uploads
   - Update file path handling

3. **Configure SharePoint Permissions**:
   - Grant App Registration access to SharePoint site
   - Configure required API permissions:
     - `Files.ReadWrite.All` or `Sites.ReadWrite.All`
     - `User.Read`

### SharePoint Site Structure

Documents should be stored in the following structure:
```
SharePoint Site Root
└── G-Cloud 15/
    └── PA Services/
        └── Cloud Support Services LOT {2a|2b|3}/
            └── {Service Name}/
                ├── PA GC15 SERVICE DESC {Service Name}.docx
                ├── PA GC15 SERVICE DESC {Service Name}.pdf
                ├── PA GC15 Pricing Doc {Service Name}.docx
                ├── questionnaire_responses.json
                └── OWNER {Owner Email}.txt
```

## Private Endpoints Configuration

### Function App

1. Navigate to Function App → Networking
2. Configure VNet integration
3. Add private endpoint
4. Configure private DNS zone

### Web App

1. Navigate to Web App → Networking
2. Configure VNet integration
3. Add private endpoint
4. Configure private DNS zone

### Key Vault

1. Navigate to Key Vault → Networking
2. Add private endpoint
3. Configure private DNS zone

## Post-Deployment Checklist

- [ ] Verify all resources created successfully
- [ ] Configure private endpoints (if required)
- [ ] Grant SharePoint permissions to App Registration
- [ ] Test authentication flow
- [ ] Complete SharePoint integration implementation
- [ ] Test document upload/download
- [ ] Verify private access (no public access)
- [ ] Configure monitoring alerts
- [ ] Review security settings

## Cleanup and Fresh Start

### Delete All Resources

To start completely fresh:

```powershell
.\scripts\cleanup-resources.ps1
```

This script will:
- Prompt you to confirm deletion (type 'DELETE')
- Delete the entire resource group and all resources within it
- **Preserve the App Registration** (it's in Azure AD, not the resource group)

**What Gets Deleted:**
- Function App
- Web App
- Key Vault
- Storage Account
- Application Insights
- Private DNS Zone
- VNet and Subnets
- Private Endpoints
- App Service Plan

**What Persists:**
- App Registration (in Azure AD - can be reused)

### After Cleanup

1. Wait for deletion to complete (check with `az group show --name <rg-name>`)
2. Pull latest changes: `git pull origin main`
3. Run fresh deployment: `.\deploy.ps1`
4. When prompted for App Registration, choose **existing** and select your App Registration

## Troubleshooting

### Frontend Not Loading / "Starting the site..."

If the frontend shows "Starting the site..." or doesn't load:
- The startup command may be incorrectly set
- Run: `.\scripts\fix-frontend-startup.ps1` to clear it
- Or redeploy with the latest scripts (they now handle this automatically)

### Authentication Issues

- Verify App Registration exists and has correct redirect URIs
- Check API permissions are granted and consented
- Verify credentials in Key Vault

### SharePoint Access Issues

- Verify App Registration has SharePoint permissions
- Check SharePoint site URL and IDs are correct
- Verify site exists and is accessible

### Private Endpoint Issues

- Verify VNet integration is configured
- Check private DNS zones are set up
- Verify network security groups allow traffic

## Support

For issues or questions, refer to:
- Main requirements: `PA-Env-Deploy.md`
- Architecture documentation in main repository
- Azure Portal for resource status

