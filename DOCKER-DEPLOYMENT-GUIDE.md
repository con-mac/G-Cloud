# Docker Container Deployment Guide

## Overview

The frontend deployment has been migrated from Azure Oryx build to Docker containers stored in Azure Container Registry (ACR). This approach:

- ✅ Eliminates runtime detection issues (PHP vs Node.js)
- ✅ Provides consistent, reliable deployments
- ✅ Matches the working Terraform deployment approach
- ✅ Works with all PA constraints (SSO, Private Endpoints, SharePoint)
- ✅ No local Node.js required for dev team (uses ACR build)

## Architecture

```
┌─────────────────────────────────┐
│  Initial Setup (One-Time)       │
│  ────────────────────────────  │
│  1. Build Docker images        │
│  2. Push to ACR                │
│     - frontend:latest          │
└─────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Azure Container Registry       │
│  ────────────────────────────  │
│  - pa-gcloud15-acr.azurecr.io   │
│  - frontend:latest              │
└─────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Dev Team Deployment            │
│  ────────────────────────────  │
│  deploy.ps1                     │
│  ├─ Creates/uses ACR            │
│  ├─ Deploys frontend container  │
│  └─ Configures app settings     │
└─────────────────────────────────┘
```

## Deployment Process

### Step 1: Initial Setup (Your Work - One Time)

**1.1. Run deployment to create ACR:**
```powershell
.\deploy.ps1
```
- When prompted for Container Registry (Step 8.5), either:
  - Select existing ACR, or
  - Create new (e.g., `pa-gcloud15-acr`)

**1.2. Build and push Docker images:**
```powershell
.\scripts\build-and-push-images.ps1
```
- Choose build method:
  - **Option 1 (ACR Build)**: Builds in Azure cloud - no local Docker needed
  - **Option 2 (Local Build)**: Builds locally with Docker Desktop, then pushes

**1.3. Complete deployment:**
```powershell
.\deploy.ps1
```
- This will deploy the frontend using the container from ACR

### Step 2: Dev Team Work (Iterative)

**2.1. Run deployment:**
```powershell
.\deploy.ps1
```
- Scripts will:
  - Detect existing ACR
  - Use existing images from ACR
  - Deploy frontend container
  - Configure all settings

**2.2. For code updates:**
- If you rebuild images and push to ACR, dev team just runs:
  ```powershell
  .\scripts\deploy-frontend.ps1
  ```
- Or run full deployment:
  ```powershell
  .\deploy.ps1
  ```

## Key Changes

### Modified Files

1. **`deploy.ps1`**
   - Added `Search-ContainerRegistries` function
   - Added ACR configuration prompt (Step 8.5)
   - Added `ACR_NAME` and `IMAGE_TAG` to config file

2. **`scripts/setup-resources.ps1`**
   - Added ACR creation logic (with existing/new handler)
   - Follows same pattern as other resources

3. **`scripts/deploy-frontend.ps1`** (Completely Rewritten)
   - Removed Oryx build logic
   - Removed zip deployment
   - Added Docker container deployment from ACR
   - Uses `az webapp config container set`

4. **`scripts/build-and-push-images.ps1`** (New)
   - Builds frontend Docker image
   - Supports both ACR build and local build
   - Pushes to ACR

### Preserved Features

✅ All existing handlers (use existing, create new, skip)  
✅ Public/private endpoint options  
✅ SSO configuration  
✅ SharePoint integration  
✅ Key Vault integration  
✅ Application Insights  
✅ All other deployment features  

## Configuration

The config file (`config/deployment-config.env`) now includes:

```env
ACR_NAME=pa-gcloud15-acr
IMAGE_TAG=latest
```

## Troubleshooting

### Image Not Found
If deployment fails with "image not found":
```powershell
# Check if image exists
az acr repository show-tags --name <ACR_NAME> --repository frontend --output table

# Rebuild if needed
.\scripts\build-and-push-images.ps1
```

### Container Won't Start
```powershell
# Check logs
az webapp log tail --name <WEB_APP_NAME> --resource-group <RESOURCE_GROUP>

# Restart app
az webapp restart --name <WEB_APP_NAME> --resource-group <RESOURCE_GROUP>
```

### ACR Access Issues
```powershell
# Ensure admin user is enabled
az acr update --name <ACR_NAME> --admin-enabled true

# Verify credentials
az acr credential show --name <ACR_NAME>
```

## Benefits

1. **Reliability**: No more runtime detection issues
2. **Consistency**: Same image works everywhere
3. **Speed**: Faster deployments (no build step)
4. **Simplicity**: Dev team just runs scripts
5. **Versioning**: Image tags for rollback capability

## Next Steps

1. Run `.\deploy.ps1` to create ACR
2. Run `.\scripts\build-and-push-images.ps1` to build images
3. Complete deployment with `.\deploy.ps1`
4. Test the frontend at `https://<WEB_APP_NAME>.azurewebsites.net`

