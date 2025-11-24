# PA Environment Deployment

This folder contains the deployment scripts and code for deploying the G-Cloud 15 automation tool to PA Consulting's Azure dev environment.

## Overview

This deployment uses:
- **SharePoint Online** for document storage (via Microsoft Graph API)
- **Microsoft 365 SSO** for authentication
- **Private endpoints** only (no public access)
- **Serverless architecture** for cost efficiency

## Current Status

### ✅ Completed
- Deployment scripts with interactive prompts
- Backend structure with placeholder API routes
- SharePoint service skeleton with Graph API placeholders
- Configuration templates
- Azure resource setup scripts
- Authentication configuration script

### ⏳ Pending Implementation
- **SharePoint Integration**: All functions in `sharepoint_service/sharepoint_online.py` are placeholders
- **Frontend Files**: Need to be copied from main repo and updated for MSAL
- **Document Generator**: Needs SharePoint upload/download implementation
- **Questionnaire Parser**: Needs to be copied from main repo

## Quick Start

1. **Copy frontend files** from main repository (see `COPY_FILES.md`)
2. **Complete SharePoint integration** in `backend/sharepoint_service/sharepoint_online.py`
3. Ensure you have Azure CLI installed and logged in
4. Ensure you have access to PA's Azure subscription
5. Run the deployment script:
   - **Bash version** (Linux/Mac/Azure Cloud Shell Bash):
     ```bash
     ./deploy.sh
     ```
   - **PowerShell version** (Windows/Azure Cloud Shell PowerShell):
     ```powershell
     .\deploy.ps1
     ```

## Prerequisites

- Azure CLI 2.0+
- Access to PA Azure subscription
- Access to SharePoint site
- App Registration created in Azure AD (or let script create it)
- VNet and private endpoints configured (or configure after deployment)

## File Structure

```
pa-deployment/
├── deploy.sh                    # Main deployment script (Bash)
├── deploy.ps1                   # Main deployment script (PowerShell)
├── scripts/                     # Deployment sub-scripts
│   ├── setup-resources.sh      # Create Azure resources (Bash)
│   ├── setup-resources.ps1     # Create Azure resources (PowerShell)
│   ├── deploy-functions.sh     # Deploy backend (Bash)
│   ├── deploy-functions.ps1    # Deploy backend (PowerShell)
│   ├── deploy-frontend.sh      # Deploy frontend (Bash)
│   ├── deploy-frontend.ps1     # Deploy frontend (PowerShell)
│   ├── configure-auth.sh        # Configure SSO (Bash)
│   └── configure-auth.ps1       # Configure SSO (PowerShell)
├── backend/                     # Backend code (placeholders)
│   ├── app/                    # FastAPI application
│   ├── function_app/           # Azure Functions entry point
│   └── sharepoint_service/     # SharePoint integration (placeholders)
├── frontend/                    # Frontend code (to be copied)
├── config/                      # Configuration templates
└── docs/                        # Documentation
```

## Documentation

- [Manual Deployment Guide](docs/PA-Manual-Deployment-Guide.md) - **Start here for step-by-step instructions**
- [Deployment Guide](docs/PA-DEPLOYMENT-GUIDE.md) - Detailed technical guide
- [Architecture Overview](../PA-Env-Deploy.md)
- [Files to Copy](COPY_FILES.md)

## Next Steps

1. **Complete SharePoint Integration**:
   - Implement Graph API calls in `sharepoint_service/sharepoint_online.py`
   - Update `document_generator.py` to use SharePoint
   - Test file upload/download

2. **Copy Frontend Files**:
   - Copy pages from main repo
   - Integrate MSAL for authentication
   - Update API base URLs

3. **Deploy**:
   - Run `./deploy.sh` (Bash) or `.\deploy.ps1` (PowerShell)
   - Configure private endpoints
   - Test end-to-end

## Repository

This folder is designed to be pushed to a separate repository for PA-specific deployments.

