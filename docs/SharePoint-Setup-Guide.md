# SharePoint Integration Setup Guide

This guide walks you through setting up SharePoint Online integration for testing your PA deployment.

## Prerequisites

- ✅ Microsoft 365 Business Basic trial (you have this)
- ✅ Access to SharePoint Online
- ✅ Access to Azure Portal (for App Registration)
- ✅ Azure CLI installed and configured

## Step 1: Get SharePoint Site URL and Site ID

### Option A: From SharePoint Site Settings

1. **Navigate to your SharePoint site** in your browser
2. **Click the gear icon** (Settings) in the top right
3. **Click "Site information"**
4. **Copy the Site URL** - it will look like:
   ```
   https://yourtenant.sharepoint.com/sites/YourSiteName
   ```
5. **To get Site ID:**
   - Go to: `https://yourtenant.sharepoint.com/sites/YourSiteName/_api/site/id`
   - Or use PowerShell (see below)

### Option B: Using PowerShell/Azure CLI

```powershell
# Login to Microsoft Graph (if needed)
az login

# Get site ID using Graph API
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/sites/yourtenant.sharepoint.com:/sites/YourSiteName" \
  --query "id" -o tsv
```

### Option C: From SharePoint URL

Your Site ID can also be extracted from the SharePoint URL structure, but the Graph API method above is more reliable.

## Step 2: Create App Registration in Microsoft Entra ID

### Via Azure Portal

1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate to**: Microsoft Entra ID → App registrations
3. **Click**: "+ New registration"
4. **Fill in**:
   - **Name**: `gcloud-sharepoint-app` (or your preferred name)
   - **Supported account types**: "Accounts in this organizational directory only"
   - **Redirect URI**: Leave blank for now (or use `http://localhost` for testing)
5. **Click**: "Register"
6. **Copy the following** (you'll need these):
   - **Application (client) ID**
   - **Directory (tenant) ID**

### Via Azure CLI

```powershell
# Create App Registration
az ad app create --display-name "gcloud-sharepoint-app" `
  --sign-in-audience "AzureADMyOrg"

# Get the App ID
$appId = az ad app list --display-name "gcloud-sharepoint-app" --query "[0].appId" -o tsv
Write-Host "App ID: $appId"

# Get Tenant ID
$tenantId = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $tenantId"
```

## Step 3: Create Client Secret

### Via Azure Portal

1. In your App Registration, go to **"Certificates & secrets"**
2. Click **"+ New client secret"**
3. **Description**: `SharePoint Integration Secret`
4. **Expires**: Choose expiration (24 months recommended)
5. **Click**: "Add"
6. **IMPORTANT**: Copy the **Value** immediately (you won't see it again!)
   - Save it securely

### Via Azure CLI

```powershell
# Create client secret
$secret = az ad app credential reset --id $appId | ConvertFrom-Json
Write-Host "Client Secret: $secret.password"
# Save this value immediately!
```

## Step 4: Configure API Permissions

### Via Azure Portal

1. In your App Registration, go to **"API permissions"**
2. Click **"+ Add a permission"**
3. Select **"Microsoft Graph"**
4. Select **"Delegated permissions"**
5. Add the following permissions:
   - `User.Read` (usually already added)
   - `Sites.ReadWrite.All` (for full SharePoint access)
   - `Files.ReadWrite.All` (alternative to Sites.ReadWrite.All)
   - `offline_access` (for refresh tokens)
6. Click **"Add permissions"**
7. **IMPORTANT**: Click **"Grant admin consent for [Your Organization]"**
   - This is required for the permissions to work

### Via Azure CLI

```powershell
# Get Microsoft Graph API ID
$graphApiId = "00000003-0000-0000-c000-000000000000"

# Add Sites.ReadWrite.All permission
az ad app permission add `
  --id $appId `
  --api $graphApiId `
  --api-permissions 205e70e5-aba6-4c52-a976-6d2d8c5c5e77=Scope

# Grant admin consent
az ad app permission admin-consent --id $appId
```

## Step 5: Grant SharePoint Site Permissions

### Via SharePoint Site

1. **Go to your SharePoint site**
2. **Click Settings** (gear icon) → **Site permissions**
3. **Click "Advanced permissions settings"**
4. **Click "Grant permissions"**
5. **Enter your App Registration name** or **Service Principal name**
   - To find Service Principal name:
     ```powershell
     az ad sp show --id $appId --query displayName -o tsv
     ```
6. **Select permission level**: "Edit" or "Full Control"
7. **Click "Share"**

### Alternative: Via Microsoft Graph API

```powershell
# Get site ID first (from Step 1)
$siteId = "your-site-id-here"

# Grant site access to app
az rest --method POST `
  --uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions" `
  --headers "Content-Type=application/json" `
  --body "{'roles':['write'],'grantedToIdentities':[{'application':{'id':'$appId','displayName':'gcloud-sharepoint-app'}}]}"
```

## Step 6: Configure Deployment Scripts

### Update deployment-config.env

When running `.\deploy.ps1`, you'll be prompted for SharePoint details. Enter:

- **SharePoint Site URL**: `https://yourtenant.sharepoint.com/sites/YourSiteName`
- **SharePoint Site ID**: (from Step 1)

The script will also create an App Registration, but you can use your existing one by entering its name when prompted.

### Manual Configuration (for local testing)

Create a file `pa-deployment/config/local-test.env`:

```env
SHAREPOINT_SITE_URL=https://yourtenant.sharepoint.com/sites/YourSiteName
SHAREPOINT_SITE_ID=your-site-id-here
AZURE_AD_TENANT_ID=your-tenant-id
AZURE_AD_CLIENT_ID=your-app-id
AZURE_AD_CLIENT_SECRET=your-client-secret
USE_SHAREPOINT=true
```

## Step 7: Test SharePoint Connection

### Using Azure CLI

```powershell
# Test Graph API access
az rest --method GET `
  --uri "https://graph.microsoft.com/v1.0/sites/$siteId" `
  --headers "Authorization=Bearer $(az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv)"
```

### Using PowerShell Script

Create `test-sharepoint.ps1`:

```powershell
# Load config
$config = @{}
Get-Content "config\local-test.env" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $config[$matches[1]] = $matches[2]
    }
}

# Get access token
$token = az account get-access-token `
    --resource https://graph.microsoft.com `
    --query accessToken -o tsv

# Test site access
az rest --method GET `
    --uri "https://graph.microsoft.com/v1.0/sites/$($config.SHAREPOINT_SITE_ID)" `
    --headers "Authorization=Bearer $token"
```

## Step 8: Update PA Deployment Scripts

The deployment scripts will automatically:
1. Store SharePoint credentials in Key Vault
2. Configure Function App with SharePoint settings
3. Set up environment variables

When running `.\deploy.ps1`, provide:
- SharePoint Site URL
- SharePoint Site ID (can be left empty to auto-detect)
- App Registration name (or let it create a new one)

## Verification Checklist

- [ ] SharePoint Site URL obtained
- [ ] SharePoint Site ID obtained
- [ ] App Registration created
- [ ] Client Secret created and saved
- [ ] API Permissions configured (Sites.ReadWrite.All)
- [ ] Admin consent granted
- [ ] SharePoint site permissions granted to App Registration
- [ ] Test connection successful
- [ ] Deployment config updated

## Troubleshooting

### "Insufficient privileges" error
- Ensure admin consent is granted for API permissions
- Verify SharePoint site permissions are granted

### "Site not found" error
- Verify Site URL is correct
- Check Site ID is correct
- Ensure App Registration has Sites.ReadWrite.All permission

### "Authentication failed" error
- Verify Client Secret is correct
- Check Tenant ID and Client ID are correct
- Ensure App Registration is active

## Next Steps

After completing this setup:
1. Run `.\deploy.ps1` to deploy your infrastructure
2. The script will use your SharePoint configuration
3. Test document upload/download functionality
4. Verify integration is working end-to-end


