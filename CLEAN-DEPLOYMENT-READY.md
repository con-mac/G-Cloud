# Clean Deployment - Ready for End-to-End Testing

## ✅ All Fixes Applied

The deployment scripts have been updated and are ready for a clean, end-to-end deployment. All known issues have been fixed:

### Fixed Issues

1. ✅ **Frontend Startup Command** - Now properly clears startup command for static site hosting
2. ✅ **App Settings Parsing** - Fixed PowerShell array building to prevent parsing errors
3. ✅ **POST_BUILD_COMMAND** - Improved to properly copy dist files to wwwroot
4. ✅ **Key Vault Permissions** - Automatically grants "Key Vault Secrets Officer" role
5. ✅ **Resource Search** - All resources (Storage, DNS, App Insights, Key Vault, App Registration) can be searched and reused
6. ✅ **Private Endpoints** - Optional during deployment (can test publicly first, then add private endpoints)
7. ✅ **Config File Parsing** - Robust parsing handles encoding and line ending issues
8. ✅ **PowerShell 5.1 Compatibility** - All scripts work on PowerShell 5.1 (no `??` operator)

## Clean Deployment Steps

### Step 1: Clean Up Existing Resources

```powershell
# Run the cleanup script
.\scripts\cleanup-resources.ps1
```

This will:
- Prompt you to type 'DELETE' to confirm
- Delete the entire resource group and all resources
- **Preserve your App Registration** (it's in Azure AD)

**Wait for deletion to complete** (check with):
```powershell
az group show --name <your-resource-group-name>
```
(Should return "ResourceNotFound" when complete)

### Step 2: Pull Latest Changes

```powershell
git pull origin main
```

### Step 3: Run Fresh Deployment

```powershell
.\deploy.ps1
```

**When prompted:**

1. **Resource Group**: 
   - Choose `n` for new
   - Enter name (e.g., `pa-gcloud15-rg`)

2. **Function App**: 
   - Choose `n` for new
   - Enter name (e.g., `pa-gcloud15-api`)

3. **Web App**: 
   - Choose `n` for new
   - Enter name (e.g., `pa-gcloud15-web`)

4. **Key Vault**: 
   - Choose `n` for new
   - Enter name (e.g., `pa-gcloud15-kv`)

5. **SharePoint Site URL**: 
   - Enter your SharePoint site URL

6. **SharePoint Site ID**: 
   - Leave empty to auto-detect, or enter manually

7. **App Registration**: 
   - Choose `existing` (your App Registration will be listed)
   - Select it from the list

8. **Storage Account**: 
   - Choose `0` for new

9. **Private DNS Zone**: 
   - Choose `0` for new

10. **Application Insights**: 
    - Choose `0` for new

11. **Private Endpoints**: 
    - Choose `n` for now (test publicly first)
    - You can add private endpoints later

### Step 4: Verify Deployment

After deployment completes:

1. **Check Function App**:
   ```powershell
   az functionapp show --name pa-gcloud15-api --resource-group pa-gcloud15-rg --query "state" -o tsv
   ```
   Should return: `Running`

2. **Check Web App**:
   ```powershell
   az webapp show --name pa-gcloud15-web --resource-group pa-gcloud15-rg --query "state" -o tsv
   ```
   Should return: `Running`

3. **Test Frontend**:
   - Open: `https://pa-gcloud15-web.azurewebsites.net`
   - Should load the React app (not "Starting the site...")

4. **Test Backend**:
   - Open: `https://pa-gcloud15-api.azurewebsites.net/api/health`
   - Should return health check response

### Step 5: Add Private Endpoints (Optional - Later)

Once you've verified everything works publicly:

```powershell
.\deploy.ps1
```

When prompted for private endpoints, choose `y`. The script will:
- Create/configure VNet
- Create subnets
- Configure VNet integration
- Create private endpoints
- Configure private DNS zones

## What's Fixed in This Deployment

### Frontend Deployment

- ✅ No startup command (Azure serves static files from wwwroot)
- ✅ Oryx build automatically runs `npm install` and `npm run build`
- ✅ POST_BUILD_COMMAND copies `dist/*` to `/home/site/wwwroot/`
- ✅ No local Node.js required

### Backend Deployment

- ✅ App settings properly configured with Key Vault references
- ✅ Connection strings stored in Key Vault
- ✅ Application Insights connection string configured

### Resource Management

- ✅ All resources can be searched and reused
- ✅ Key Vault permissions automatically granted
- ✅ Config file properly parsed and validated

## Expected Deployment Time

- **Resource Creation**: 5-10 minutes
- **Backend Deployment**: 2-3 minutes
- **Frontend Build & Deployment**: 5-10 minutes (Oryx build)
- **Auth Configuration**: 1-2 minutes

**Total**: ~15-25 minutes

## Troubleshooting

### If Frontend Shows "Starting the site..."

The deployment script now handles this automatically, but if it still happens:

```powershell
.\scripts\fix-frontend-startup.ps1
```

### If Deployment Fails

1. Check the error message
2. Verify you have permissions for all resources
3. Check Azure Portal for resource status
4. Run cleanup and try again

### If Resources Already Exist

The script will detect existing resources and let you:
- Use existing
- Create new
- Skip (for optional resources)

## Ready for Production

Once you've verified everything works:
1. Test all features
2. Add private endpoints (run `.\deploy.ps1` again, choose `y`)
3. Configure access restrictions
4. Set up monitoring alerts

## Support

All scripts are in `pa-deployment/scripts/`:
- `deploy.ps1` - Main deployment script
- `setup-resources.ps1` - Creates Azure resources
- `deploy-functions.ps1` - Deploys backend
- `deploy-frontend.ps1` - Deploys frontend (Oryx build)
- `configure-auth.ps1` - Configures SSO
- `cleanup-resources.ps1` - Deletes all resources
- `fix-frontend-startup.ps1` - Fixes startup command if needed

