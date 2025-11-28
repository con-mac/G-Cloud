# PA Environment Manual Deployment Guide

This guide provides step-by-step instructions for manually deploying the G-Cloud 15 automation tool to PA Consulting's Azure dev environment using the deployment scripts.

## Overview

This deployment uses:
- **SharePoint Online** for document storage (via Microsoft Graph API)
- **Microsoft 365 SSO** for authentication
- **Private endpoints** for secure access
- **Azure Functions** for backend API
- **App Service** for frontend hosting

## Prerequisites

Before starting, ensure you have:

1. **Azure CLI** installed and configured
   ```bash
   # Check installation
   az --version
   
   # Login to Azure
   az login
   
   # Set correct subscription
   az account set --subscription "PA-Azure-Subscription-Name"
   ```

2. **Access Requirements**:
   - Access to PA's Azure subscription
   - Contributor or Owner role on the subscription/resource group
   - Access to SharePoint site where documents will be stored
   - Permission to create App Registrations in Azure AD

3. **Required Information**:
   - SharePoint site URL (e.g., `https://paconsulting.sharepoint.com/sites/GCloud15`)
   - SharePoint site ID (optional, can be auto-detected)
   - Desired resource names (or use defaults)

## Deployment Methods

You can deploy using either **Bash** or **PowerShell** scripts:

### Option 1: Automated Deployment (Recommended)

The deployment scripts handle all resource creation and configuration automatically.

#### Using Bash (Linux/Mac/Azure Cloud Shell Bash)

```bash
# Clone repository
git clone https://github.com/con-mac/g-cloud-v15.git
cd g-cloud-v15/pa-deployment

# Make scripts executable
chmod +x deploy.sh scripts/*.sh

# Run deployment
./deploy.sh
```

#### Using PowerShell (Windows/Azure Cloud Shell PowerShell)

```powershell
# Clone repository
git clone https://github.com/con-mac/g-cloud-v15.git
cd g-cloud-v15/pa-deployment

# Run deployment
.\deploy.ps1
```

The script will:
1. Check prerequisites
2. Prompt for configuration values
3. Create all Azure resources
4. Deploy backend code
5. Deploy frontend code
6. Configure authentication

### Option 2: Manual Step-by-Step Deployment

If you prefer to run each step manually or need more control:

#### Step 1: Setup Azure Resources

**Bash:**
```bash
./scripts/setup-resources.sh
```

**PowerShell:**
```powershell
.\scripts\setup-resources.ps1
```

This creates:
- Resource Group
- Storage Account (for temporary files)
- Key Vault (for secrets)
- Function App (for backend API)
- App Service Plan and Web App (for frontend)
- Application Insights (for monitoring)

#### Step 2: Deploy Backend Functions

**Bash:**
```bash
./scripts/deploy-functions.sh
```

**PowerShell:**
```powershell
.\scripts\deploy-functions.ps1
```

This:
- Packages backend code
- Deploys to Function App
- Configures app settings
- Sets up Key Vault references

#### Step 3: Deploy Frontend

**Bash:**
```bash
./scripts/deploy-frontend.sh
```

**PowerShell:**
```powershell
.\scripts\deploy-frontend.ps1
```

This:
- Builds React frontend
- Creates production environment file
- Deploys to Web App
- Configures app settings

#### Step 4: Configure Authentication

**Bash:**
```bash
./scripts/configure-auth.sh
```

**PowerShell:**
```powershell
.\scripts\configure-auth.ps1
```

This:
- Creates App Registration (if needed)
- Generates client secret
- Stores credentials in Key Vault
- Configures Function App and Web App with auth settings

## Configuration File

The deployment scripts create a configuration file at `config/deployment-config.env`:

```env
RESOURCE_GROUP=pa-gcloud15-rg
FUNCTION_APP_NAME=pa-gcloud15-api
WEB_APP_NAME=pa-gcloud15-web
KEY_VAULT_NAME=pa-gcloud15-kv
SHAREPOINT_SITE_URL=https://paconsulting.sharepoint.com/sites/GCloud15
SHAREPOINT_SITE_ID=
APP_REGISTRATION_NAME=pa-gcloud15-app
CUSTOM_DOMAIN=PA-G-Cloud15
LOCATION=uksouth
SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

You can edit this file and re-run individual scripts if needed.

## Post-Deployment Configuration

### 1. Configure SharePoint Permissions

The App Registration needs permissions to access SharePoint:

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Find your app registration (e.g., `pa-gcloud15-app`)
3. Go to **API permissions**
4. Click **Add a permission** → **Microsoft Graph** → **Delegated permissions**
5. Add the following permissions:
   - `User.Read`
   - `Files.ReadWrite.All` (or `Sites.ReadWrite.All`)
   - `offline_access`
6. Click **Add permissions**
7. Click **Grant admin consent for [Your Organization]**

### 2. Configure SharePoint Site Permissions

Grant the App Registration access to your SharePoint site:

1. Go to your SharePoint site
2. Click **Settings** → **Site permissions**
3. Click **Advanced permissions settings**
4. Click **Grant permissions**
5. Enter the App Registration name or service principal
6. Grant **Edit** or **Full Control** permissions
7. Click **Share**

### 3. Add Secrets to Key Vault

Some secrets need to be added manually:

```bash
# Storage connection string (if using storage for temp files)
az keyvault secret set \
    --vault-name pa-gcloud15-kv \
    --name StorageConnectionString \
    --value "DefaultEndpointsProtocol=https;AccountName=..."

# SharePoint credentials (if using service principal)
az keyvault secret set \
    --vault-name pa-gcloud15-kv \
    --name SharePointClientId \
    --value "your-client-id"

az keyvault secret set \
    --vault-name pa-gcloud15-kv \
    --name SharePointClientSecret \
    --value "your-client-secret"
```

### 4. Configure Private Endpoints (Optional but Recommended)

For secure, private access:

1. **Create VNet** (if not exists):
   ```bash
   az network vnet create \
       --resource-group pa-gcloud15-rg \
       --name pa-gcloud15-vnet \
       --address-prefix 10.0.0.0/16 \
       --subnet-name default \
       --subnet-prefix 10.0.1.0/24
   ```

2. **Create Private DNS Zone**:
   ```bash
   az network private-dns zone create \
       --resource-group pa-gcloud15-rg \
       --name privatelink.azurewebsites.net
   ```

3. **Create Private Endpoint for Function App**:
   ```bash
   az network private-endpoint create \
       --resource-group pa-gcloud15-rg \
       --name pe-function-app \
       --vnet-name pa-gcloud15-vnet \
       --subnet default \
       --private-connection-resource-id /subscriptions/.../resourceGroups/pa-gcloud15-rg/providers/Microsoft.Web/sites/pa-gcloud15-api \
       --group-id sites \
       --connection-name pe-function-app-connection
   ```

4. **Link Private DNS Zone**:
   ```bash
   az network private-dns link vnet create \
       --resource-group pa-gcloud15-rg \
       --zone-name privatelink.azurewebsites.net \
       --name dns-link \
       --virtual-network pa-gcloud15-vnet \
       --registration-enabled false
   ```

### 5. Configure VNet Integration

Enable VNet integration for Function App and Web App:

```bash
# Function App VNet integration
az functionapp vnet-integration add \
    --resource-group pa-gcloud15-rg \
    --name pa-gcloud15-api \
    --vnet pa-gcloud15-vnet \
    --subnet default

# Web App VNet integration
az webapp vnet-integration add \
    --resource-group pa-gcloud15-rg \
    --name pa-gcloud15-web \
    --vnet pa-gcloud15-vnet \
    --subnet default
```

## Verification

### 1. Test Function App

```bash
# Get Function App URL
FUNCTION_URL=$(az functionapp show \
    --name pa-gcloud15-api \
    --resource-group pa-gcloud15-rg \
    --query defaultHostName -o tsv)

# Test health endpoint
curl https://${FUNCTION_URL}/api/v1/health
```

### 2. Test Web App

```bash
# Get Web App URL
WEB_URL=$(az webapp show \
    --name pa-gcloud15-web \
    --resource-group pa-gcloud15-rg \
    --query defaultHostName -o tsv)

# Open in browser
echo "https://${WEB_URL}"
```

### 3. Test Authentication

1. Navigate to the Web App URL
2. Click "Sign In"
3. You should be redirected to Microsoft 365 login
4. After login, you should be redirected back to the app

### 4. Test SharePoint Integration

```bash
# Test SharePoint connection (via Function App)
curl -X GET "https://${FUNCTION_URL}/api/v1/sharepoint/test" \
    -H "Authorization: Bearer YOUR_TOKEN"
```

## Troubleshooting

### Function App Not Deploying

**Issue**: `func azure functionapp publish` fails

**Solutions**:
- Ensure Azure Functions Core Tools is installed:
  ```bash
  npm install -g azure-functions-core-tools@4
  ```
- Check Function App exists:
  ```bash
  az functionapp show --name pa-gcloud15-api --resource-group pa-gcloud15-rg
  ```
- Verify Python runtime:
  ```bash
  az functionapp config show --name pa-gcloud15-api --resource-group pa-gcloud15-rg --query linuxFxVersion
  ```

### Frontend Build Fails

**Issue**: `npm run build` fails

**Solutions**:
- Ensure Node.js 18+ is installed
- Check `package.json` exists in frontend directory
- Verify all dependencies are installed:
  ```bash
  cd frontend
  npm install
  ```

### Authentication Not Working

**Issue**: Users can't sign in

**Solutions**:
- Verify App Registration redirect URI matches Web App URL
- Check API permissions are granted with admin consent
- Verify Key Vault secrets are accessible:
  ```bash
  az keyvault secret show --vault-name pa-gcloud15-kv --name AzureADClientId
  ```

### SharePoint Access Denied

**Issue**: Cannot access SharePoint files

**Solutions**:
- Verify App Registration has correct API permissions
- Check SharePoint site permissions for the service principal
- Verify SharePoint site URL and ID are correct
- Check Key Vault secrets for SharePoint credentials

### Private Endpoint Issues

**Issue**: Cannot access resources via private endpoint

**Solutions**:
- Verify VNet integration is enabled
- Check private DNS zone is linked to VNet
- Verify private endpoint is created and approved
- Check network security groups allow traffic

## Updating Deployment

To update an existing deployment:

1. **Pull latest code**:
   ```bash
   git pull
   ```

2. **Re-run deployment scripts** (they will update existing resources):
   ```bash
   ./deploy.sh
   # or
   .\deploy.ps1
   ```

3. **Or update specific components**:
   ```bash
   # Update backend only
   ./scripts/deploy-functions.sh
   
   # Update frontend only
   ./scripts/deploy-frontend.sh
   ```

## Cleanup

To remove all resources:

```bash
# Delete resource group (removes everything)
az group delete --name pa-gcloud15-rg --yes --no-wait

# Or delete individual resources
az functionapp delete --name pa-gcloud15-api --resource-group pa-gcloud15-rg
az webapp delete --name pa-gcloud15-web --resource-group pa-gcloud15-rg
az keyvault delete --name pa-gcloud15-kv --resource-group pa-gcloud15-rg
```

## Additional Resources

- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/overview)
- [SharePoint REST API Documentation](https://docs.microsoft.com/en-us/sharepoint/dev/sp-add-ins/get-to-know-the-sharepoint-rest-service)
- [Azure Private Endpoints](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Portal logs:
   - Function App: **Monitor** → **Log stream**
   - Web App: **Monitoring** → **Log stream**
3. Check Application Insights for detailed errors
4. Review Key Vault access policies

