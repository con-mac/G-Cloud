# Redeployment Checklist

## ⚠️ BEFORE DELETING - Save These Values

### 1. **App Registration** (KEEP THIS - Select "Use Existing" during redeploy)
- **Name**: `pa-gcloud15-app` (or whatever you named it)
- **Why**: Contains all API permissions for SharePoint, Graph API, etc.
- **Action**: During `deploy.ps1` Step 6, select the existing App Registration

### 2. **Security Groups** (KEEP THESE - Select "Use Existing" during redeploy)
- **Admin Group Name**: `G-Cloud-Admins` (or whatever you named it)
- **Employee Group Name**: `G-Cloud-Employees` (if you created one)
- **Why**: These control who can access admin dashboard vs standard view
- **Action**: During `deploy.ps1` Steps 6.5 and 6.6, select existing groups

### 3. **SharePoint Site Information**
- **Site URL**: e.g., `https://conmacdev.sharepoint.com/sites/Gcloud`
- **Site ID**: The GUID (without query parameters)
- **Why**: Needed to reconnect the app to SharePoint
- **Action**: Have this ready for Step 5 in `deploy.ps1`

## 🗑️ WILL BE DELETED (Recreated Automatically)

These are in the resource group and will be recreated:
- ✅ Function App (backend)
- ✅ Web App (frontend)
- ✅ Key Vault (will be recreated)
- ✅ Storage Account
- ✅ Application Insights
- ✅ Container Registry (ACR) - **Docker images will be lost**
- ✅ Private DNS Zone
- ✅ VNet/Subnets (if created)
- ✅ Private Endpoints (if created)

## 📋 REDEPLOYMENT STEPS

### Step 1: Delete Resource Group
```powershell
az group delete --name <your-resource-group-name> --yes --no-wait
```

**⚠️ Key Vault Note**: If Key Vault was soft-deleted, you may need to purge it:
```powershell
az keyvault purge --name <key-vault-name>
```

### Step 2: Run Deployment
```powershell
.\deploy.ps1
```

**Important selections:**
- **Step 6**: Select existing App Registration (don't create new)
- **Step 6.5**: Select existing Admin Security Group (or create if needed)
- **Step 6.6**: Select existing Employee Security Group (optional)
- **Step 8.5**: You can reuse ACR name or create new (images will be rebuilt anyway)

### Step 3: Rebuild Docker Image (CRITICAL for SSO)
After deployment completes, rebuild the frontend image to embed SSO values:

```powershell
.\scripts\build-and-push-images.ps1
```

**Why**: The Docker image needs to be rebuilt with the real tenant ID and client ID embedded at build time. The build script will automatically:
- Get tenant ID from Azure
- Get client ID from App Registration
- Get admin group ID from config
- Pass them as build args to embed in the image

### Step 4: Redeploy Frontend
```powershell
.\scripts\deploy-frontend.ps1
```

### Step 5: Verify SharePoint Permissions
The App Registration should still have permissions, but verify:
- Go to Azure Portal → App Registrations → Your App
- Check "API permissions" → Should show SharePoint permissions
- If missing, run `.\scripts\configure-auth.ps1` again

## 🔍 POST-DEPLOYMENT VERIFICATION

1. **SSO Login**: 
   - Should work automatically (no manual role selection)
   - Admin group members → Admin dashboard
   - Others → Standard employee view

2. **Admin Dashboard Access**:
   - Try accessing `/admin/dashboard` as non-admin → Should redirect to `/proposals`
   - Only admin group members should see admin dashboard

3. **SharePoint Connectivity**:
   - Test document upload/retrieval
   - Verify App Registration has SharePoint permissions

## ⚡ QUICK REFERENCE

**What to keep:**
- ✅ App Registration (select existing)
- ✅ Security Groups (select existing)
- ✅ SharePoint site info

**What gets recreated:**
- 🔄 All Azure resources (Function App, Web App, Key Vault, etc.)
- 🔄 Docker images (must rebuild for SSO)

**Critical step:**
- ⚠️ **Must rebuild Docker image** after deployment for SSO to work!

