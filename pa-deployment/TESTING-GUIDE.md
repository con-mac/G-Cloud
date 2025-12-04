# Testing Guide - Post-Deployment Verification

This guide helps you verify that your deployment is working correctly.

## Prerequisites

- All resources deployed successfully
- SPA platform configured in App Registration
- API permissions added and admin consent granted
- Key Vault secrets configured (if needed)

## Step 1: Test Frontend Access

### 1.1 Open the Web App
```
https://pa-gcloud15-web-14sxir.azurewebsites.net
```

**Expected:**
- Page loads (may show login screen)
- No blank white page
- No console errors (check browser DevTools)

**If blank page:**
- Check browser console for errors
- Verify Docker container is running: `az webapp log tail --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg`
- Restart Web App: `az webapp restart --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg`

## Step 2: Test SSO Authentication

### 2.1 Try to Login
1. Click "Sign In" or navigate to a protected page
2. You should be redirected to Microsoft login
3. Sign in with your Microsoft 365 account

**Expected:**
- Redirects to Microsoft login
- After login, redirects back to app
- User profile loads (name, email visible)
- No "Cross-origin token redemption" error

**If "Cross-origin token redemption" error:**
- SPA platform not configured correctly
- Run: `.\pa-deployment\scripts\fix-spa-platform-urgent.ps1`
- Or manually verify SPA platform in Azure Portal

**If login fails:**
- Check App Registration redirect URIs
- Verify SPA platform is configured
- Check browser console for errors

## Step 3: Test Backend API

### 3.1 Test API Health
```powershell
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/health
```

**Expected:**
- Returns JSON with status: `{"status": "healthy"}` or similar
- No 404 or 500 errors

**If 404:**
- Function App may not be deployed
- Check: `az functionapp list --resource-group pa-gcloud15-rg`

**If 500:**
- Check Function App logs: `az functionapp log tail --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg`

### 3.2 Test API Endpoints
```powershell
# Test proposals endpoint (may require auth)
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/proposals/

# Test SharePoint endpoint
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/sharepoint/test
```

## Step 4: Test SharePoint Connectivity

### 4.1 Automated Test
```powershell
.\pa-deployment\scripts\test-sharepoint-connectivity.ps1
```

### 4.2 Manual Test
```powershell
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/sharepoint/test
```

**Expected Response:**
```json
{
  "connected": true,
  "site_id": "IQDXgGc-TLKFRr2ZG3Zl74hTAcd4CRIeTp1BeB05ffsTkVc",
  "site_url": "https://conmacdev.sharepoint.com/sites/Gcloud",
  "message": "Successfully connected to SharePoint"
}
```

**If "SharePoint credentials not configured":**
- Key Vault secrets missing
- Run: `.\pa-deployment\scripts\check-keyvault-access.ps1`
- Add secrets to Key Vault manually if needed

**If "Tenant does not have SPO license":**
- This is a test tenant limitation
- Will work in production tenant
- Not a blocker for deployment verification

**If "Unauthorized" or "Forbidden":**
- API permissions not granted
- Admin consent not granted
- Run: `.\pa-deployment\scripts\fix-sharepoint-permissions-v2.ps1`

## Step 5: Test Key Vault Access

### 5.1 Check Managed Identity
```powershell
.\pa-deployment\scripts\check-keyvault-access.ps1
```

**Expected:**
- Managed identity enabled
- Key Vault access granted
- Secrets accessible

**If access denied:**
- Run: `.\pa-deployment\scripts\fix-keyvault-access.ps1`

## Step 6: Test Full User Flow

### 6.1 End-to-End Test
1. **Open frontend:** https://pa-gcloud15-web-14sxir.azurewebsites.net
2. **Login:** Sign in with Microsoft 365
3. **Navigate:** Try accessing different pages
4. **Create proposal:** (if applicable)
5. **Access SharePoint:** (if applicable)

**Expected:**
- All pages load
- No authentication errors
- Data loads from backend
- SharePoint integration works (if applicable)

## Step 7: Check Logs (if issues)

### 7.1 Function App Logs
```powershell
az functionapp log tail --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg
```

### 7.2 Web App Logs
```powershell
az webapp log tail --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg
```

### 7.3 Application Insights
- Go to: Azure Portal → Application Insights → pa-gcloud15-api-14sxir-insights
- Check "Logs" for errors

## Quick Test Checklist

- [ ] Frontend loads: https://pa-gcloud15-web-14sxir.azurewebsites.net
- [ ] SSO login works (no "Cross-origin" error)
- [ ] Backend API responds: `/api/v1/health`
- [ ] SharePoint test endpoint works: `/api/v1/sharepoint/test`
- [ ] Key Vault access verified
- [ ] No errors in browser console
- [ ] No errors in Function App logs

## Common Issues & Fixes

### Issue: Blank white page
**Fix:**
```powershell
az webapp restart --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg
# Wait 30 seconds, then refresh
```

### Issue: "Cross-origin token redemption" error
**Fix:**
```powershell
.\pa-deployment\scripts\fix-spa-platform-urgent.ps1
```

### Issue: SharePoint test fails
**Fix:**
```powershell
# 1. Fix permissions
.\pa-deployment\scripts\fix-sharepoint-permissions-v2.ps1

# 2. Fix Key Vault access
.\pa-deployment\scripts\fix-keyvault-access.ps1

# 3. Restart Function App
az functionapp restart --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg
```

### Issue: API returns 404
**Fix:**
- Verify Function App is deployed
- Check function is registered: `az functionapp function list --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg`

### Issue: API returns 500
**Fix:**
- Check logs: `az functionapp log tail --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg`
- Verify app settings are configured
- Check Key Vault references are correct

## Verification Commands

```powershell
# Check Function App status
az functionapp show --name pa-gcloud15-api-14sxir --resource-group pa-gcloud15-rg --query "state"

# Check Web App status
az webapp show --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg --query "state"

# Check App Registration
az ad app list --display-name "pa-gcloud15-app" --query "[0].{Name:displayName, AppId:appId}"

# Test API endpoint
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/health

# Test SharePoint
curl https://pa-gcloud15-api-14sxir.azurewebsites.net/api/v1/sharepoint/test
```

## Success Criteria

✅ **Deployment is successful if:**
1. Frontend loads and displays correctly
2. SSO login works without errors
3. Backend API responds to health check
4. SharePoint test endpoint returns success (or tenant limitation message)
5. No critical errors in logs
6. User can navigate the application

## Next Steps After Testing

If all tests pass:
1. Add users to Admin Security Group (for admin dashboard access)
2. Configure additional Key Vault secrets (if needed)
3. Set up monitoring alerts
4. Configure private endpoints (if required)
5. Document any custom configurations

