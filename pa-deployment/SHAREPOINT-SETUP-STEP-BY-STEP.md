# SharePoint Setup - Step-by-Step Guide

## Quick Reference Checklist

Use this checklist during deployment:

- [ ] **Step 1:** API Permissions configured (Application permissions added)
- [ ] **Step 2:** Admin Consent granted (REQUIRED - Manual in Portal)
- [ ] **Step 3:** Site-Level Permissions granted (REQUIRED - Manual in SharePoint)
- [ ] **Step 4:** Managed Identity enabled for Function App
- [ ] **Step 5:** Key Vault Secrets User role assigned
- [ ] **Step 6:** Key Vault references set in Function App settings
- [ ] **Step 7:** Function App restarted
- [ ] **Step 8:** SharePoint connectivity verified

---

## Overview

SharePoint access requires **THREE security layers**:

1. **API Permissions** - What the app can do (defined in App Registration)
2. **Admin Consent** - Administrator approval (REQUIRED for Application permissions)
3. **Site-Level Permissions** - Access to specific SharePoint site (REQUIRED)

All three must be configured correctly for SharePoint access to work.

---

## Step 1: Configure API Permissions

**What:** Add Application permissions to the App Registration for SharePoint access.

**Why:** Defines what the app is allowed to do with SharePoint.

**How:** Run the automated script:

```powershell
.\pa-deployment\scripts\fix-sharepoint-permissions-v2.ps1
```

**Expected Output:**
```
[INFO] Fixing SharePoint permissions for: pa-gcloud15-app
[INFO] Removing existing SharePoint permissions...
[SUCCESS] All specified permissions removed.
[INFO] Adding required Application permissions...
[SUCCESS] ✓ Sites.FullControl.All (Application) added
[SUCCESS] ✓ Sites.ReadWrite.All (Application) added
[SUCCESS] ✓ Files.ReadWrite.All (Application) added
[SUCCESS] ✓ User.Read (Delegated) added
[ERROR] Failed to grant admin consent automatically
[WARNING] MANUAL STEPS REQUIRED: [See Step 2]
```

**Verification:**
```powershell
.\pa-deployment\scripts\verify-sharepoint-permissions.ps1
```

**Expected:** All Application permissions should be listed (but may show "Not granted" until Step 2).

---

## Step 2: Grant Admin Consent (REQUIRED - Manual)

**What:** An Azure AD administrator must explicitly approve the Application permissions.

**Why:** Application permissions are powerful and require admin approval for security.

**How:** Manual step in Azure Portal:

1. Go to: https://portal.azure.com
2. Navigate to: **Azure Active Directory** → **App registrations**
3. Find your app: `pa-gcloud15-app` (or the name from your config)
4. Click: **API permissions** (left menu)
5. Click: **Grant admin consent for [your tenant name]**
6. Click: **Yes** when prompted
7. Wait 1-2 minutes for propagation

**Expected Outcome:**
- All Application permissions show: **✓ Granted for [tenant name]**
- Status changes from "Not granted" to "Granted"

**Verification:**
```powershell
.\pa-deployment\scripts\verify-sharepoint-permissions.ps1
```

**Expected Output:**
```
[SUCCESS] Sites.FullControl.All (Application): ✓ Granted
[SUCCESS] Sites.ReadWrite.All (Application): ✓ Granted
[SUCCESS] Files.ReadWrite.All (Application): ✓ Granted
```

**If verification fails:** The admin consent may not have propagated yet. Wait 2-3 minutes and try again, or verify manually in Azure Portal.

---

## Step 3: Grant Site-Level Permissions (REQUIRED - Manual)

**What:** Grant the App Registration access to the specific SharePoint site.

**Why:** API permissions grant the ability; site-level permissions grant access to the specific site.

**How:** Manual step in SharePoint (choose ONE method):

### Method A: Via SharePoint Site UI (Recommended)

1. Go to your SharePoint site: `https://conmacdev.sharepoint.com/sites/Gcloud` (or your site URL)
2. Click **Settings** (gear icon, top right)
3. Click **Site permissions**
4. Click **Grant permissions** (or **Share**)
5. In the "Share" dialog:
   - Enter: `pa-gcloud15-app` (or search for it)
   - Or enter the App ID: `0b006bcf-c014-4d3f-8b89-d002a353bd8a` (from your config)
6. Select permission level: **Edit** or **Full Control**
7. Click **Share**

### Method B: Via SharePoint Admin Center

1. Go to: https://admin.microsoft.com
2. Navigate to: **SharePoint** → **Sites** → **Active sites**
3. Find your site
4. Click on the site name
5. Go to **Permissions** tab
6. Add the App Registration: `pa-gcloud15-app` (App ID: `0b006bcf-c014-4d3f-8b89-d002a353bd8a`)
7. Grant **Edit** or **Full Control** permissions

**Expected Outcome:**
- App Registration appears in the site's permissions list
- Permission level shows as "Edit" or "Full Control"

**Verification:**
- Go to SharePoint Site → Settings → Site permissions
- Verify the App Registration appears in the list

**If verification fails:** The App Registration may need to be added again, or you may need to wait a few minutes for permissions to propagate.

---

## Step 4: Enable Managed Identity and Key Vault Access

**What:** Enable system-assigned managed identity for the Function App and grant it access to Key Vault.

**Why:** The Function App needs managed identity to read secrets from Key Vault.

**How:** Run the automated script:

```powershell
.\pa-deployment\scripts\fix-keyvault-access.ps1
```

**Expected Output:**
```
[INFO] Enabling managed identity for Function App: pa-gcloud15-api
[SUCCESS] Managed identity enabled for Function App
[INFO] Principal ID: 789d9947-c5ff-477f-9c6b-1951091a3e73
[INFO] Granting Key Vault access to Function App managed identity...
[SUCCESS] Key Vault access granted to Function App managed identity
[SUCCESS] Setup complete! The Function App can now read secrets from Key Vault.
```

**Verification:**
```powershell
.\pa-deployment\scripts\check-keyvault-access.ps1
```

**Expected Output:**
```
[SUCCESS] ✓ Managed identity enabled: 789d9947-c5ff-477f-9c6b-1951091a3e73
[SUCCESS] ✓ Key Vault Secrets User role assigned
[SUCCESS] ✓ Secret exists: AzureADTenantId
[SUCCESS] ✓ Secret exists: AzureADClientId
[SUCCESS] ✓ Secret exists: AzureADClientSecret
```

**If verification fails:**
- If managed identity is missing: Run `fix-keyvault-access.ps1` again
- If role assignment is missing: Run the command from the script output manually:
  ```powershell
  az role assignment create --role 'Key Vault Secrets User' --assignee <PRINCIPAL_ID> --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.KeyVault/vaults/<KEY_VAULT_NAME>
  ```

---

## Step 5: Set Key Vault References in Function App

**What:** Configure Function App settings to use Key Vault references for Azure AD credentials.

**Why:** Keeps secrets secure in Key Vault instead of storing them directly in app settings.

**How:** Choose ONE method:

### Method A: Via Azure Portal (Recommended - Most Reliable)

1. Go to: https://portal.azure.com
2. Search for: `pa-gcloud15-api` (your Function App name)
3. Click: **Configuration** → **Application settings**
4. For each setting below, click **+ New application setting**:

   **Setting 1: AZURE_AD_TENANT_ID**
   - Name: `AZURE_AD_TENANT_ID`
   - Toggle **"Key Vault Reference"** ON
   - Select Key Vault: `pa-gcloud15-kv`
   - Select Secret: `AzureADTenantId`
   - Click **OK**

   **Setting 2: AZURE_AD_CLIENT_ID**
   - Name: `AZURE_AD_CLIENT_ID`
   - Toggle **"Key Vault Reference"** ON
   - Select Key Vault: `pa-gcloud15-kv`
   - Select Secret: `AzureADClientId`
   - Click **OK**

   **Setting 3: AZURE_AD_CLIENT_SECRET**
   - Name: `AZURE_AD_CLIENT_SECRET`
   - Toggle **"Key Vault Reference"** ON
   - Select Key Vault: `pa-gcloud15-kv`
   - Select Secret: `AzureADClientSecret`
   - Click **OK**

5. Click **Save** at the top
6. Confirm when prompted

### Method B: Via PowerShell (If Portal method fails)

```powershell
# Get your Key Vault name from config
$KEY_VAULT_NAME = "pa-gcloud15-kv"  # Update if different
$kvUri = "https://${KEY_VAULT_NAME}.vault.azure.net"

# Set each one with single quotes to avoid PowerShell parsing issues
az functionapp config appsettings set `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --settings 'AZURE_AD_TENANT_ID=@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADTenantId/)'

az functionapp config appsettings set `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --settings 'AZURE_AD_CLIENT_ID=@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADClientId/)'

az functionapp config appsettings set `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --settings 'AZURE_AD_CLIENT_SECRET=@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADClientSecret/)'
```

**Expected Outcome:**
- All three settings appear in Function App configuration
- Each setting shows as a Key Vault reference (starts with `@Microsoft.KeyVault`)

**Verification:**
```powershell
.\pa-deployment\scripts\verify-keyvault-refs.ps1
```

**Expected Output:**
```
[SUCCESS] AZURE_AD_TENANT_ID: Key Vault Reference
[SUCCESS] AZURE_AD_CLIENT_ID: Key Vault Reference
[SUCCESS] AZURE_AD_CLIENT_SECRET: Key Vault Reference
```

**If verification fails:**
- Check that the Key Vault references have closing parentheses: `)`
- Verify secrets exist in Key Vault: `az keyvault secret list --vault-name pa-gcloud15-kv`
- Try the Portal method instead (Method A)

---

## Step 6: Restart Function App

**What:** Restart the Function App to apply all configuration changes.

**Why:** Function App needs to restart to:
- Pick up new app settings
- Refresh managed identity tokens
- Apply Key Vault access changes

**How:**
```powershell
az functionapp restart --name pa-gcloud15-api --resource-group pa-gcloud15-rg
```

**Expected Output:**
```
(No output - command completes silently)
```

**Wait Time:** 2-3 minutes for the Function App to fully restart.

**Verification:**
```powershell
# Check Function App status
az functionapp show --name pa-gcloud15-api --resource-group pa-gcloud15-rg --query "state" -o tsv
```

**Expected:** `Running`

---

## Step 7: Test SharePoint Connectivity

**What:** Verify that the Function App can successfully connect to SharePoint.

**Why:** Confirms all three security layers are working correctly.

**How:**
```powershell
curl https://pa-gcloud15-api.azurewebsites.net/api/v1/sharepoint/test
```

**Expected Success Response:**
```json
{
  "connected": true,
  "site_id": "IQDXgGc-TLKFRr2ZG3Zl74hTAcd4CRIeTp1BeB05ffsTkVc",
  "site_url": "https://conmacdev.sharepoint.com/sites/Gcloud",
  "message": "Successfully connected to SharePoint"
}
```

**Common Error Responses and Solutions:**

### Error: "Tenant does not have a SPO license"
```json
{
  "error": "Tenant does not have a SPO license"
}
```
**Solution:** The tenant doesn't have SharePoint Online enabled. This is expected for test tenants. For production, use a tenant with SharePoint Online licenses.

### Error: "Key Vault reference not resolved"
```json
{
  "error": "Tenant ID is a Key Vault reference but could not be resolved"
}
```
**Solution:**
1. Verify managed identity is enabled: `.\pa-deployment\scripts\check-keyvault-access.ps1`
2. Verify Key Vault Secrets User role is assigned
3. Wait 2-3 minutes for propagation
4. Restart Function App again

### Error: "Access denied" or "Forbidden"
```json
{
  "error": "Access denied"
}
```
**Solution:**
1. Verify admin consent is granted (Step 2)
2. Verify site-level permissions are granted (Step 3)
3. Check Function App logs for detailed error:
   ```powershell
   az functionapp log tail --name pa-gcloud15-api --resource-group pa-gcloud15-rg
   ```

### Error: "Insufficient privileges"
```json
{
  "error": "Insufficient privileges to complete the operation"
}
```
**Solution:** Admin consent not granted. Complete Step 2.

---

## Troubleshooting

### Issue: Key Vault references show as `null` in app settings

**Symptoms:** `verify-keyvault-refs.ps1` shows values as null or empty.

**Solution:**
1. Use Azure Portal method (Step 5, Method A) - most reliable
2. Verify Key Vault references have closing parentheses: `)`
3. Check that secrets exist in Key Vault

### Issue: Managed identity can't read from Key Vault

**Symptoms:** Error: "Could not read secret from Key Vault"

**Solution:**
1. Run: `.\pa-deployment\scripts\check-keyvault-access.ps1`
2. If role assignment is missing, run: `.\pa-deployment\scripts\fix-keyvault-access.ps1`
3. Wait 2-3 minutes for propagation
4. Restart Function App

### Issue: Admin consent keeps failing

**Symptoms:** Script shows "Failed to grant admin consent automatically"

**Solution:** This is expected - admin consent MUST be done manually in Azure Portal (Step 2). The script cannot grant admin consent automatically for security reasons.

### Issue: Site-level permissions can't be granted via API

**Symptoms:** `grant-sharepoint-site-access.ps1` fails

**Solution:** This is expected - site-level permissions are best granted manually via SharePoint UI (Step 3, Method A). The API method often fails due to SharePoint security policies.

### Issue: Function App logs show Key Vault errors

**How to check logs:**
```powershell
# Stream logs
az functionapp log tail --name pa-gcloud15-api --resource-group pa-gcloud15-rg

# Or view in Portal
# https://portal.azure.com -> pa-gcloud15-api -> Log stream
```

**Common log errors:**
- `ManagedIdentityCredential authentication failed` → Managed identity not enabled or role not assigned
- `Secret not found` → Secret doesn't exist in Key Vault or wrong name
- `Access denied` → Key Vault Secrets User role not assigned

---

## Verification Scripts Reference

All verification scripts are in `pa-deployment/scripts/`:

| Script | Purpose |
|--------|---------|
| `verify-sharepoint-permissions.ps1` | Verify API permissions and admin consent |
| `check-keyvault-access.ps1` | Verify managed identity and Key Vault access |
| `verify-keyvault-refs.ps1` | Verify Key Vault references in app settings |
| `check-azure-ad-settings.ps1` | Check all Azure AD credential settings |

---

## Complete Verification Command

After completing all steps, run this comprehensive check:

```powershell
# 1. Check API permissions and admin consent
.\pa-deployment\scripts\verify-sharepoint-permissions.ps1

# 2. Check Key Vault access
.\pa-deployment\scripts\check-keyvault-access.ps1

# 3. Check Key Vault references
.\pa-deployment\scripts\verify-keyvault-refs.ps1

# 4. Test SharePoint connectivity
curl https://pa-gcloud15-api.azurewebsites.net/api/v1/sharepoint/test
```

**Expected:** All checks should pass, and the SharePoint test should return `"connected": true` (or a licensing error if using a test tenant without SharePoint Online).

---

## Next Steps After Successful Setup

1. **Monitor Function App logs** for any SharePoint access issues
2. **Test SharePoint operations** (read files, create folders, etc.)
3. **Review security** - ensure only required permissions are granted
4. **Document production tenant** - note any differences for PA Consulting tenant setup

---

## Production Deployment Notes

When deploying to production (PA Consulting tenant):

1. **App Registration** must be created in the PA Consulting tenant
2. **SharePoint Site** must be in the PA Consulting tenant
3. **Users** must sign in with `@paconsulting.com` email addresses
4. **Admin Consent** must be granted by a PA Consulting Azure AD admin
5. **Site-Level Permissions** must be granted on the production SharePoint site

All steps remain the same, but use production values:
- Tenant: `paconsulting.com`
- SharePoint Site: `paconsulting.sharepoint.com/sites/GCloud15` (or similar)
- App Registration: Created in PA Consulting tenant

