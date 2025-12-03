# SharePoint Security Configuration Guide

## Overview

SharePoint access requires **THREE separate security layers**. All three must be configured correctly for the App Registration to access SharePoint.

## Security Layers

### 1. API Permissions (App Registration)

**What it is:** Permissions defined in the Azure AD App Registration that specify what the app can do.

**Required Permissions:**
- `Sites.FullControl.All` (Application permission) - Full control of all site collections
- `Sites.ReadWrite.All` (Application permission) - Read and write access to all site collections
- `Files.ReadWrite.All` (Application permission) - Read and write access to all files
- `User.Read` (Delegated permission) - For frontend SSO

**How to configure:**
```powershell
.\pa-deployment\scripts\fix-sharepoint-permissions-v2.ps1
```

**Status:** ✅ Configured (but needs admin consent)

---

### 2. Admin Consent (REQUIRED)

**What it is:** An Azure AD administrator must explicitly grant consent for Application permissions. This is a security requirement - Application permissions are powerful and require admin approval.

**Why it's required:**
- Application permissions allow the app to act on behalf of the organization, not just a single user
- This is different from Delegated permissions (which act on behalf of a signed-in user)
- Admin consent ensures an administrator has reviewed and approved the permissions

**How to grant:**
1. Go to: https://portal.azure.com
2. Navigate to: **Azure Active Directory** → **App registrations**
3. Find your app: `pa-gcloud15-app`
4. Click: **API permissions** (left menu)
5. Click: **Grant admin consent for [your tenant name]**
6. Click: **Yes** when prompted
7. Verify all permissions show "✓ Granted for [tenant]"

**Status:** ⚠️ **MANUAL STEP REQUIRED** - The automated script failed, you must do this manually

**Important:** Without admin consent, Application permissions will NOT work, even if they're configured.

---

### 3. SharePoint Site-Level Permissions

**What it is:** The App Registration must be explicitly granted access to the specific SharePoint site. This is separate from API permissions.

**Why it's required:**
- API permissions grant the app the *ability* to access SharePoint
- Site-level permissions grant the app access to a *specific* site
- SharePoint has its own permission model independent of Azure AD

**How to grant (Choose ONE method):**

#### Method A: Via SharePoint Site UI (Easiest)

1. Go to your SharePoint site: `https://conmacdev.sharepoint.com/sites/Gcloud`
2. Click **Settings** (gear icon, top right)
3. Click **Site permissions**
4. Click **Grant permissions** (or **Share**)
5. In the "Share" dialog:
   - Enter: `pa-gcloud15-app` (or search for it)
   - Or enter the App ID: `0b006bcf-c014-4d3f-8b89-d002a353bd8a`
6. Select permission level: **Edit** or **Full Control**
7. Click **Share**

#### Method B: Via SharePoint Admin Center

1. Go to: https://admin.microsoft.com
2. Navigate to: **SharePoint** → **Sites** → **Active sites**
3. Find your site: `https://conmacdev.sharepoint.com/sites/Gcloud`
4. Click on the site name
5. Go to **Permissions** tab
6. Add the App Registration: `pa-gcloud15-app` (`0b006bcf-c014-4d3f-8b89-d002a353bd8a`)
7. Grant **Edit** or **Full Control** permissions

#### Method C: Via PowerShell (Advanced)

```powershell
# Install SharePoint Online Management Shell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell

# Connect to SharePoint Admin
Connect-SPOService -Url https://conmacdev-admin.sharepoint.com

# Grant access to site
Add-SPOSiteGroup -Site "https://conmacdev.sharepoint.com/sites/Gcloud" `
    -Group "Members" `
    -LoginName "0b006bcf-c014-4d3f-8b89-d002a353bd8a"
```

**Status:** ⚠️ **MANUAL STEP REQUIRED** - Automated methods often fail, manual configuration is most reliable

---

## Why All Three Are Needed

```
┌─────────────────────────────────────────────────────────┐
│ 1. API Permissions                                      │
│    "This app CAN access SharePoint"                     │
│    (Defines what the app is allowed to do)             │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Admin Consent                                        │
│    "An admin APPROVED this app accessing SharePoint"   │
│    (Security gate - prevents unauthorized apps)         │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Site-Level Permissions                               │
│    "This app CAN access THIS SPECIFIC SharePoint site"  │
│    (Grants access to the actual site)                   │
└─────────────────────────────────────────────────────────┘
```

**Analogy:**
- API Permissions = Having a driver's license (you're allowed to drive)
- Admin Consent = Having insurance (an authority verified you're safe)
- Site-Level Permissions = Having a key to a specific car (you can access this specific resource)

---

## User Email and Tenant Context

### Current Setup (Development/Test)

- **Tenant:** `conmacdev.onmicrosoft.com` (test tenant)
- **SharePoint Site:** `conmacdev.sharepoint.com/sites/Gcloud`
- **User Email:** `conor.macklin1986@gmail.com` (personal Gmail)
- **App Registration:** `pa-gcloud15-app` in `conmacdev.onmicrosoft.com` tenant

**This is a test/dev setup.** For production, you'll need:

### Production Setup (PA Consulting)

- **Tenant:** `paconsulting.com` (PA Consulting tenant)
- **SharePoint Site:** `paconsulting.sharepoint.com/sites/GCloud15` (or similar)
- **User Email Format:** `firstName.LastName@paconsulting.com`
- **App Registration:** Needs to be created in PA Consulting tenant

**Important Notes:**
1. The App Registration must be in the **same tenant** as the SharePoint site
2. Users must sign in with **PA Consulting email addresses** (`@paconsulting.com`)
3. The App Registration will only have access to SharePoint sites in its tenant
4. Cross-tenant access requires special configuration (not recommended)

---

## Verification Checklist

Use this checklist to verify all security layers are configured:

- [ ] **API Permissions:**
  - [ ] `Sites.FullControl.All` (Application) - Added
  - [ ] `Sites.ReadWrite.All` (Application) - Added
  - [ ] `Files.ReadWrite.All` (Application) - Added
  - [ ] `User.Read` (Delegated) - Added

- [ ] **Admin Consent:**
  - [ ] All Application permissions show "✓ Granted for [tenant]"
  - [ ] Verified in Azure Portal → App registrations → API permissions

- [ ] **Site-Level Permissions:**
  - [ ] App Registration appears in SharePoint site permissions
  - [ ] Permission level is "Edit" or "Full Control"
  - [ ] Verified in SharePoint Site → Settings → Site permissions

- [ ] **Function App Configuration:**
  - [ ] Managed identity enabled
  - [ ] Key Vault access granted
  - [ ] Azure AD credentials stored in Key Vault
  - [ ] Key Vault references set in Function App settings

---

## Troubleshooting

### Error: "SharePoint credentials not configured"
- **Cause:** Function App can't read credentials from Key Vault
- **Fix:** Run `.\pa-deployment\scripts\set-azure-ad-keyvault-refs.ps1`

### Error: "Insufficient privileges to complete the operation"
- **Cause:** Admin consent not granted
- **Fix:** Manually grant admin consent in Azure Portal

### Error: "Access denied" or "Forbidden"
- **Cause:** Site-level permissions not granted
- **Fix:** Grant access via SharePoint Site UI (Method A above)

### Error: "Invalid client secret"
- **Cause:** Client secret expired or incorrect
- **Fix:** Create new client secret in App Registration → Certificates & secrets

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `fix-sharepoint-permissions-v2.ps1` | Configure API permissions (Layer 1) |
| `grant-sharepoint-site-access.ps1` | Grant site-level permissions (Layer 3) |
| `set-azure-ad-keyvault-refs.ps1` | Set Key Vault references in Function App |
| `check-azure-ad-settings.ps1` | Verify credential configuration |
| `verify-sharepoint-permissions.ps1` | Verify API permissions and admin consent |

---

## Next Steps

1. **Grant Admin Consent** (Manual - required)
   - Azure Portal → App registrations → `pa-gcloud15-app` → API permissions → Grant admin consent

2. **Grant Site-Level Permissions** (Manual - recommended)
   - SharePoint Site → Settings → Site permissions → Grant permissions → Add App Registration

3. **Set Key Vault References** (Automated)
   ```powershell
   .\pa-deployment\scripts\set-azure-ad-keyvault-refs.ps1
   ```

4. **Restart Function App**
   ```powershell
   az functionapp restart --name pa-gcloud15-api --resource-group pa-gcloud15-rg
   ```

5. **Test SharePoint Connectivity**
   ```powershell
   curl https://pa-gcloud15-api.azurewebsites.net/api/v1/sharepoint/test
   ```

---

## Security Best Practices

1. **Least Privilege:** Only grant the minimum permissions needed
   - For read-only access, use `Sites.Read.All` instead of `Sites.FullControl.All`
   - For specific sites, use `Sites.Selected` instead of `Sites.FullControl.All`

2. **Regular Audits:** Periodically review:
   - App Registration permissions
   - Site-level permissions
   - Who has access to Key Vault secrets

3. **Secret Rotation:** Rotate client secrets regularly (every 90 days recommended)

4. **Monitoring:** Monitor Function App logs for authentication failures

5. **Production vs. Dev:** Use separate App Registrations for production and development

