# End-to-End Deployment Checklist

This document summarizes what's **baked into `deploy.ps1`** and what requires **manual steps** after deployment.

## ✅ Fully Automated (Baked In)

### 1. Resource Creation
- ✅ Resource Group
- ✅ Function App (backend API)
- ✅ Web App (frontend)
- ✅ Key Vault
- ✅ Storage Account (if needed)
- ✅ Application Insights
- ✅ Private DNS Zone (if needed)
- ✅ ACR (Container Registry)

### 2. Backend Deployment
- ✅ Function App code deployment using Azure Functions Core Tools (reliable method)
- ✅ Automatic dependency installation (`requirements.txt`)
- ✅ Build settings configured (`SCM_DO_BUILD_DURING_DEPLOYMENT=true`)
- ✅ App settings configured (SharePoint, Key Vault references, etc.)

### 3. Frontend Deployment
- ✅ Docker image build in Azure (no local Docker needed)
- ✅ Image push to ACR
- ✅ Web App configured with Docker container
- ✅ Environment variables injected at runtime

### 4. Authentication Setup
- ✅ App Registration created/configured
- ✅ **SPA platform configured using Graph API** (fixes MSAL login errors)
- ✅ Client secret created and stored in Key Vault
- ✅ Managed identity enabled for Function App
- ✅ Key Vault access granted to Function App managed identity
- ✅ Security groups created/configured (admin and employee)
- ✅ App settings configured for SSO

### 5. Verification
- ✅ SPA platform verification after deployment
- ✅ Config file validation
- ✅ Resource existence checks

## ⚠️ Post-Deployment Manual Steps

These steps are **required** but may need manual intervention:

### Step 1: Verify SPA Platform (CRITICAL)
**Why:** MSAL.js requires SPA platform type for cross-origin token redemption.

**Automated Option:**
```powershell
.\scripts\fix-spa-platform-urgent.ps1
```

**Manual Option (if script fails):**
1. Azure Portal → Azure AD → App registrations
2. Find your App Registration
3. Authentication → Add platform → Single-page application
4. Add redirect URI: `https://<your-web-app>.azurewebsites.net`
5. Configure

### Step 2: SharePoint Permissions
**Why:** Application permissions require admin consent.

**Automated Option:**
```powershell
.\scripts\fix-sharepoint-permissions-v2.ps1
```

**Then manually grant admin consent:**
1. Azure Portal → App registrations → Your app
2. API permissions
3. Click "Grant admin consent for [tenant]"
4. Confirm

**Manual Option:**
1. Azure Portal → App registrations → Your app
2. API permissions → Add permission → Microsoft Graph → Application permissions
3. Add: `Sites.FullControl.All`, `Sites.ReadWrite.All`, `Files.ReadWrite.All`
4. Grant admin consent

### Step 3: Test Everything
```powershell
# Test authentication
# Open: https://<your-web-app>.azurewebsites.net

# Test SharePoint connectivity
.\scripts\test-sharepoint-connectivity.ps1
# Or: curl https://<your-function-app>.azurewebsites.net/api/v1/sharepoint/test
```

## 🔧 Quick Fix Scripts (Available)

If something goes wrong, these scripts are ready:

- `fix-spa-platform-urgent.ps1` - Fixes MSAL login errors
- `fix-sharepoint-permissions-v2.ps1` - Fixes SharePoint permissions
- `fix-keyvault-access.ps1` - Fixes Key Vault access
- `test-sharepoint-connectivity.ps1` - Tests SharePoint connection
- `check-keyvault-access.ps1` - Diagnoses Key Vault issues
- `check-app-settings.ps1` - Verifies Function App settings

## 📝 What Changed (Latest Updates)

### SPA Platform Fix
- **Problem:** MSAL login failed with "Cross-origin token redemption" error
- **Solution:** `configure-auth.ps1` now uses Graph API to explicitly create SPA platform type
- **Status:** ✅ Baked into `deploy.ps1`

### SharePoint Permissions
- **Problem:** Delegated permissions instead of Application permissions
- **Solution:** `fix-sharepoint-permissions-v2.ps1` removes all and adds correct ones
- **Status:** ⚠️ Run after deployment (admin consent must be manual)

### Key Vault Access
- **Problem:** Function App couldn't read Key Vault secrets
- **Solution:** Managed identity enabled and "Key Vault Secrets User" role granted
- **Status:** ✅ Baked into `configure-auth.ps1`

### Dependency Installation
- **Problem:** Dependencies not installing during deployment
- **Solution:** Uses Azure Functions Core Tools (`func azure functionapp publish`)
- **Status:** ✅ Baked into `deploy-functions.ps1`

## 🚀 Fresh Deployment Tomorrow

When you run `deploy.ps1` from scratch:

1. **Everything automated** will run automatically
2. **SPA platform** will be configured correctly (Graph API method)
3. **Key Vault access** will be set up automatically
4. **After deployment**, you'll see clear next steps with:
   - Automated script options
   - Manual portal instructions
   - Copy-paste commands for verification

## 💡 Philosophy

**Automated when reliable, manual when needed.**

- Scripts are provided for convenience
- Manual steps are documented and acceptable
- Portal work is fine if scripts fail
- Copy-paste commands are provided for quick fixes

## 📞 Troubleshooting

If login fails:
→ Run `fix-spa-platform-urgent.ps1` or use manual portal steps

If SharePoint test fails:
→ Run `fix-sharepoint-permissions-v2.ps1` + grant admin consent manually

If Key Vault access fails:
→ Run `fix-keyvault-access.ps1`

If dependencies missing:
→ Run `deploy-with-dependencies.ps1` (uses Functions Core Tools)

