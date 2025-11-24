# Manual Azure Portal Deployment Guide
## Cost-Effective Private Serverless Architecture

This guide provides step-by-step instructions for manually deploying the G-Cloud Proposal Automation application to Azure Portal using the cost-effective serverless approach with blocked internet public access.

**Reference Document**: `Azure_Cost_Saving_Private_Serverless.md`

---

## Prerequisites

Before starting, ensure you have:
- ✅ Azure Portal access with Owner or Contributor permissions
- ✅ Access to PA's Virtual Network (VNet)
- ✅ Access to shared App Service Environment (ASE) - if available
- ✅ Azure CLI installed and logged in (`az login`)
- ✅ Git repository cloned locally
- ✅ Application code ready for deployment

---

## Architecture Overview

**Components to Deploy:**
1. **Resource Group** - Container for all resources
2. **Storage Account** - Blob storage for documents (with Private Endpoint)
3. **Function App (Backend API)** - FastAPI service (Consumption plan)
4. **Function App (Frontend)** - React SPA static file server (Consumption plan)
5. **Function App (PDF Converter)** - LibreOffice conversion service (Container)
6. **Key Vault** - Secrets management (with Private Endpoint)
7. **Private DNS Zone** - Friendly private URLs (pa.internal)
8. **Application Insights** - Monitoring and telemetry

**Network Configuration:**
- All services use Private Endpoints (no public internet access)
- Functions deployed to shared App Service Environment (ASE)
- Private DNS Zone for friendly URLs (e.g., `gcloud-app.pa.internal`)

---

## Step 1: Create Resource Group

### Azure Portal Steps

1. Navigate to **Azure Portal** → **Resource groups**
2. Click **+ Create**
3. Fill in the form:
   - **Subscription**: Select your subscription
   - **Resource group**: `gcloud-prod-rg` (or your preferred name)
   - **Region**: Select your region (e.g., `UK South`)
4. Click **Review + create**, then **Create**

### Azure CLI Alternative

```bash
az group create \
  --name gcloud-prod-rg \
  --location uksouth
```

**Copy this command** → Execute in Azure Cloud Shell or local terminal

---

## Step 2: Create Storage Account with Private Endpoint

### 2.1 Create Storage Account

1. In Azure Portal, navigate to **Storage accounts**
2. Click **+ Create**
3. Fill in the form:
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Storage account name**: `gcloudprodst` (must be globally unique, lowercase, alphanumeric)
   - **Region**: Same as Resource Group
   - **Performance**: Standard
   - **Redundancy**: LRS (Locally Redundant Storage)
4. Click **Review + create**, then **Create**

### 2.2 Create Blob Container

1. Navigate to the created Storage Account
2. Go to **Containers** (left menu)
3. Click **+ Container**
4. Fill in:
   - **Name**: `sharepoint`
   - **Public access level**: Private (no anonymous access)
5. Click **Create**

### 2.3 Configure Private Endpoint

1. In Storage Account, go to **Networking** (left menu)
2. Click **Private endpoint connections** tab
3. Click **+ Private endpoint**
4. Fill in:
   - **Name**: `gcloud-storage-pe`
   - **Region**: Same as Storage Account
   - **Target sub-resource**: `blob`
5. Click **Next: Virtual Network**
6. Select:
   - **Virtual network**: PA's VNet
   - **Subnet**: Select appropriate subnet (e.g., `10.0.1.0/24`)
   - **Private IP configuration**: Use dynamic IP allocation
7. Click **Next: DNS**
8. Select:
   - **Integrate with private DNS zone**: Yes
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Private DNS zone**: Create new `privatelink.blob.core.windows.net`
9. Click **Review + create**, then **Create**

### Azure CLI Alternative

```bash
# Create Storage Account
az storage account create \
  --name gcloudprodst \
  --resource-group gcloud-prod-rg \
  --location uksouth \
  --sku Standard_LRS \
  --kind StorageV2

# Create Container
az storage container create \
  --name sharepoint \
  --account-name gcloudprodst \
  --auth-mode login \
  --public-access off

# Get Storage Account ID
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name gcloudprodst \
  --resource-group gcloud-prod-rg \
  --query id -o tsv)

# Create Private Endpoint
az network private-endpoint create \
  --name gcloud-storage-pe \
  --resource-group gcloud-prod-rg \
  --vnet-name <PA_VNET_NAME> \
  --subnet <SUBNET_NAME> \
  --private-connection-resource-id $STORAGE_ACCOUNT_ID \
  --group-id blob \
  --connection-name gcloud-storage-connection
```

**Replace** `<PA_VNET_NAME>` and `<SUBNET_NAME>` with your actual VNet details.

---

## Step 3: Create Key Vault with Private Endpoint

### 3.1 Create Key Vault

1. Navigate to **Key Vaults**
2. Click **+ Create**
3. Fill in:
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Key vault name**: `gcloud-prod-kv` (must be globally unique)
   - **Region**: Same as Resource Group
   - **Pricing tier**: Standard
4. Click **Review + create**, then **Create**

### 3.2 Configure Private Endpoint

1. In Key Vault, go to **Networking**
2. Click **Private endpoint connections** tab
3. Click **+ Private endpoint**
4. Fill in:
   - **Name**: `gcloud-kv-pe`
   - **Region**: Same as Key Vault
   - **Target sub-resource**: `vault`
5. Click **Next: Virtual Network**
6. Select PA's VNet and subnet
7. Click **Next: DNS**
8. Select:
   - **Integrate with private DNS zone**: Yes
   - **Private DNS zone**: Create new `privatelink.vaultcore.azure.net`
9. Click **Review + create**, then **Create**

### 3.3 Add Secrets

1. In Key Vault, go to **Secrets**
2. Click **+ Generate/Import** for each secret:

**Secret 1: Storage Connection String**
- **Name**: `storage-connection-string`
- **Value**: Get from Storage Account → **Access keys** → **Connection string** (key1)

**Secret 2: Application Secret Key**
- **Name**: `secret-key`
- **Value**: Generate a secure random string (32+ characters)

**Secret 3: Database URL** (if using database)
- **Name**: `database-url`
- **Value**: `postgresql://user:password@host:5432/dbname`

### Azure CLI Alternative

```bash
# Create Key Vault
az keyvault create \
  --name gcloud-prod-kv \
  --resource-group gcloud-prod-rg \
  --location uksouth \
  --sku standard

# Get Storage Connection String
STORAGE_CONN=$(az storage account show-connection-string \
  --name gcloudprodst \
  --resource-group gcloud-prod-rg \
  --query connectionString -o tsv)

# Add Secrets
az keyvault secret set \
  --vault-name gcloud-prod-kv \
  --name storage-connection-string \
  --value "$STORAGE_CONN"

az keyvault secret set \
  --vault-name gcloud-prod-kv \
  --name secret-key \
  --value "$(openssl rand -base64 32)"

# Create Private Endpoint
KEY_VAULT_ID=$(az keyvault show \
  --name gcloud-prod-kv \
  --resource-group gcloud-prod-rg \
  --query id -o tsv)

az network private-endpoint create \
  --name gcloud-kv-pe \
  --resource-group gcloud-prod-rg \
  --vnet-name <PA_VNET_NAME> \
  --subnet <SUBNET_NAME> \
  --private-connection-resource-id $KEY_VAULT_ID \
  --group-id vault \
  --connection-name gcloud-kv-connection
```

---

## Step 4: Create Application Insights

1. Navigate to **Application Insights**
2. Click **+ Create**
3. Fill in:
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Name**: `gcloud-prod-insights`
   - **Region**: Same as Resource Group
   - **Resource Mode**: Classic (or Workspace-based)
4. Click **Review + create**, then **Create**

**Save the Instrumentation Key** - You'll need it for Function Apps.

### Azure CLI Alternative

```bash
az monitor app-insights component create \
  --app gcloud-prod-insights \
  --location uksouth \
  --resource-group gcloud-prod-rg

# Get Instrumentation Key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app gcloud-prod-insights \
  --resource-group gcloud-prod-rg \
  --query instrumentationKey -o tsv)

echo "Instrumentation Key: $INSTRUMENTATION_KEY"
```

---

## Step 5: Create Function App (Backend API)

### 5.1 Create Function App

1. Navigate to **Function Apps**
2. Click **+ Create**
3. Fill in **Basics** tab:
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Function app name**: `gcloud-api-prod` (must be globally unique)
   - **Publish**: Code
   - **Runtime stack**: Python
   - **Version**: 3.10 or 3.11
   - **Region**: Same as Resource Group
4. Click **Next: Hosting**
5. Fill in:
   - **Storage account**: Select `gcloudprodst` (created earlier)
   - **Operating System**: Linux
   - **Plan type**: **Consumption (Serverless)** or **App Service Plan** (if using ASE)
6. If using **App Service Plan**:
   - **App Service Plan**: Select existing shared ASE plan (or create new)
   - **Sku and size**: Consumption (Y1) or Premium (if ASE)
7. Click **Next: Networking**
8. **Important for Private Access**:
   - **Public access**: **Disabled** (if using Private Endpoint)
   - Or configure **VNet integration** if using ASE
9. Click **Next: Monitoring**
10. Select:
    - **Enable Application Insights**: Yes
    - **Application Insights**: Select `gcloud-prod-insights`
11. Click **Review + create**, then **Create**

### 5.2 Configure Application Settings

1. Navigate to the Function App
2. Go to **Configuration** → **Application settings**
3. Click **+ New application setting** for each:

**Required Settings:**
```
AZURE_STORAGE_CONNECTION_STRING = <Get from Key Vault secret: storage-connection-string>
AZURE_STORAGE_CONTAINER_NAME = sharepoint
APPINSIGHTS_INSTRUMENTATIONKEY = <From Application Insights>
APPLICATIONINSIGHTS_CONNECTION_STRING = <From Application Insights>
```

**Optional Settings:**
```
ENVIRONMENT = production
DEBUG = False
SECRET_KEY = <Get from Key Vault secret: secret-key>
```

4. Click **Save**

### 5.3 Configure Managed Identity

1. In Function App, go to **Identity**
2. Turn **On** System assigned managed identity
3. **Save**
4. Go to Key Vault → **Access policies**
5. Click **+ Add Access Policy**
6. Select:
   - **Secret permissions**: Get, List
   - **Select principal**: Search for Function App name `gcloud-api-prod`
7. Click **Add**, then **Save**

### 5.4 Configure Private Endpoint (if not using ASE)

1. In Function App, go to **Networking**
2. Click **Private endpoint connections**
3. Click **+ Add**
4. Fill in:
   - **Name**: `gcloud-api-pe`
   - **Target sub-resource**: `sites`
   - **Virtual network**: PA's VNet
   - **Subnet**: Select subnet
   - **Private DNS integration**: Yes (create `privatelink.azurewebsites.net`)
5. Click **OK**

### Azure CLI Alternative

```bash
# Create Storage Account for Function App (if not using existing)
az storage account create \
  --name gcloudfuncst \
  --resource-group gcloud-prod-rg \
  --location uksouth \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  --name gcloud-api-prod \
  --resource-group gcloud-prod-rg \
  --storage-account gcloudfuncst \
  --consumption-plan-location uksouth \
  --runtime python \
  --runtime-version 3.10 \
  --functions-version 4 \
  --os-type Linux

# Enable Managed Identity
az functionapp identity assign \
  --name gcloud-api-prod \
  --resource-group gcloud-prod-rg

# Get Managed Identity Principal ID
PRINCIPAL_ID=$(az functionapp identity show \
  --name gcloud-api-prod \
  --resource-group gcloud-prod-rg \
  --query principalId -o tsv)

# Grant Key Vault Access
az keyvault set-policy \
  --name gcloud-prod-kv \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list

# Configure Application Settings
STORAGE_CONN=$(az keyvault secret show \
  --vault-name gcloud-prod-kv \
  --name storage-connection-string \
  --query value -o tsv)

INSTR_KEY=$(az monitor app-insights component show \
  --app gcloud-prod-insights \
  --resource-group gcloud-prod-rg \
  --query instrumentationKey -o tsv)

az functionapp config appsettings set \
  --name gcloud-api-prod \
  --resource-group gcloud-prod-rg \
  --settings \
    AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN" \
    AZURE_STORAGE_CONTAINER_NAME=sharepoint \
    APPINSIGHTS_INSTRUMENTATIONKEY="$INSTR_KEY"
```

---

## Step 6: Deploy Backend API Code

### 6.1 Prepare Deployment Package

**On your local machine**, run:

```bash
# Navigate to project root
cd /path/to/gcloud_automate

# Create build directory
mkdir -p build/api_function
cd build/api_function

# Install dependencies
pip install --target .python_packages/lib/site-packages -r ../../backend/requirements.txt

# Copy backend files (excluding unnecessary files)
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'tests' \
  --exclude 'build' \
  ../../backend/ .

# Copy function_app and host.json
cp -R ../../backend/function_app .
cp ../../backend/host.json .
cp ../../backend/requirements.txt .

# Include docs folder
mkdir -p docs
cp -r ../../docs/* docs/

# Include mock_sharepoint if exists
if [ -d "../../mock_sharepoint" ]; then
  cp -r ../../mock_sharepoint .
fi

# Create zip package
zip -r function.zip .
```

### 6.2 Deploy via Azure Portal

1. In Function App, go to **Deployment Center**
2. Select **External Git** or **Local Git** or **Zip Deploy**
3. For **Zip Deploy**:
   - Go to **Advanced Tools (Kudu)** → **Go**
   - Navigate to **Tools** → **Zip Push Deploy**
   - Upload `function.zip` created above

### 6.3 Deploy via Azure CLI

```bash
# From the build/api_function directory
az functionapp deployment source config-zip \
  --resource-group gcloud-prod-rg \
  --name gcloud-api-prod \
  --src function.zip
```

---

## Step 7: Create Function App (Frontend - React SPA)

### 7.1 Build React Application

**On your local machine:**

```bash
cd frontend

# Install dependencies
npm ci

# Build with API URL
VITE_API_BASE_URL=https://gcloud-api-prod.azurewebsites.net npm run build

# The dist/ folder contains the built React app
```

### 7.2 Create Frontend Function App

1. Navigate to **Function Apps**
2. Click **+ Create**
3. Fill in **Basics**:
   - **Function app name**: `gcloud-frontend-prod`
   - **Publish**: Code
   - **Runtime stack**: Python
   - **Version**: 3.10
   - **Region**: Same as Resource Group
4. **Hosting**:
   - **Storage account**: `gcloudfuncst` (or create new)
   - **Plan type**: Consumption (Serverless)
5. **Networking**: Same as backend (Private Endpoint or VNet integration)
6. **Monitoring**: Use same Application Insights
7. Click **Create**

### 7.3 Create Frontend Function Code

**Create a new function in the Function App:**

1. In Function App, go to **Functions**
2. Click **+ Create**
3. Select **HTTP trigger**
4. Fill in:
   - **New Function**: `serve_spa`
   - **Authorization level**: Function (or Anonymous for private endpoint)
5. Click **Create**

### 7.4 Upload Frontend Function Code

**Create `function_app.py` in the Function App:**

```python
import azure.functions as func
import os
from pathlib import Path
import mimetypes

def main(req: func.HttpRequest) -> func.HttpResponse:
    # Get requested path
    path = req.params.get('path', '')
    if not path or path == '/':
        path = 'index.html'
    
    # Remove leading slash
    path = path.lstrip('/')
    
    # Security: prevent directory traversal
    if '..' in path:
        return func.HttpResponse("Forbidden", status_code=403)
    
    # Static file directory (where React build is deployed)
    static_dir = Path(__file__).parent / 'static'
    file_path = static_dir / path
    
    # Check if file exists
    if not file_path.exists() or not file_path.is_file():
        # SPA routing: serve index.html for all non-file requests
        file_path = static_dir / 'index.html'
    
    # Read and serve file
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
    except Exception as e:
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)
    
    # Determine content type
    content_type, _ = mimetypes.guess_type(str(file_path))
    if not content_type:
        if path.endswith('.js'):
            content_type = 'application/javascript'
        elif path.endswith('.css'):
            content_type = 'text/css'
        else:
            content_type = 'text/html'
    
    return func.HttpResponse(
        content,
        mimetype=content_type,
        status_code=200
    )
```

**Deploy React build to Function:**

1. Create `static/` folder in Function App
2. Copy all files from `frontend/dist/` to `static/`
3. Deploy via Zip Deploy (same as backend)

---

## Step 8: Create Function App (PDF Converter)

### 8.1 Create Container-based Function App

1. Navigate to **Function Apps**
2. Click **+ Create**
3. Fill in:
   - **Function app name**: `gcloud-pdf-converter-prod`
   - **Publish**: Docker Container
   - **Operating System**: Linux
   - **Plan type**: Consumption (Serverless)
4. Click **Next: Docker**
5. Fill in:
   - **Image Source**: Azure Container Registry (or Docker Hub)
   - **Image and tag**: Your PDF converter image
6. Configure networking (Private Endpoint)
7. Click **Create**

### 8.2 Build and Push Docker Image

**On your local machine:**

```bash
cd backend/pdf_converter

# Build image
docker build -f Dockerfile.azure -t gcloud-pdf-converter:latest .

# Tag for Azure Container Registry
docker tag gcloud-pdf-converter:latest <ACR_NAME>.azurecr.io/gcloud-pdf-converter:latest

# Push to ACR
az acr login --name <ACR_NAME>
docker push <ACR_NAME>.azurecr.io/gcloud-pdf-converter:latest
```

---

## Step 9: Configure Private DNS Zone

### 9.1 Create Private DNS Zone

1. Navigate to **Private DNS zones**
2. Click **+ Create**
3. Fill in:
   - **Subscription**: Your subscription
   - **Resource group**: `gcloud-prod-rg`
   - **Name**: `pa.internal` (or `paconsulting.internal`)
4. Click **Review + create**, then **Create**

### 9.2 Link to Virtual Network

1. In Private DNS Zone, go to **Virtual network links**
2. Click **+ Add**
3. Fill in:
   - **Link name**: `pa-vnet-link`
   - **Virtual network**: Select PA's VNet
   - **Enable auto-registration**: No
4. Click **OK**

### 9.3 Create A Records

1. In Private DNS Zone, go to **Overview**
2. Click **+ Record set**
3. Create A record for backend:
   - **Name**: `gcloud-api`
   - **Type**: A
   - **TTL**: 300
   - **IP address**: Private Endpoint IP of Function App (from Step 5.4)
4. Click **OK**

5. Create A record for frontend:
   - **Name**: `gcloud-app`
   - **Type**: A
   - **TTL**: 300
   - **IP address**: Private Endpoint IP of Frontend Function App
6. Click **OK**

### Azure CLI Alternative

```bash
# Create Private DNS Zone
az network private-dns zone create \
  --resource-group gcloud-prod-rg \
  --name pa.internal

# Link to VNet
az network private-dns link vnet create \
  --resource-group gcloud-prod-rg \
  --zone-name pa.internal \
  --name pa-vnet-link \
  --virtual-network <PA_VNET_ID> \
  --registration-enabled false

# Get Private Endpoint IPs (replace with actual IPs)
API_PE_IP="10.0.1.100"  # From Function App Private Endpoint
FRONTEND_PE_IP="10.0.1.101"  # From Frontend Function App Private Endpoint

# Create A Records
az network private-dns record-set a create \
  --resource-group gcloud-prod-rg \
  --zone-name pa.internal \
  --name gcloud-api \
  --ttl 300

az network private-dns record-set a add-record \
  --resource-group gcloud-prod-rg \
  --zone-name pa.internal \
  --name gcloud-api \
  --ipv4-address $API_PE_IP

az network private-dns record-set a create \
  --resource-group gcloud-prod-rg \
  --zone-name pa.internal \
  --name gcloud-app \
  --ttl 300

az network private-dns record-set a add-record \
  --resource-group gcloud-prod-rg \
  --zone-name pa.internal \
  --name gcloud-app \
  --ipv4-address $FRONTEND_PE_IP
```

---

## Step 10: Configure Network Access Rules

### 10.1 Disable Public Access on Storage Account

1. Navigate to Storage Account → **Networking**
2. Select **Private endpoint connections and selected virtual networks**
3. **Save**

### 10.2 Configure Function App Network Access

1. In Function App → **Networking**
2. Under **Inbound traffic**, ensure:
   - **Public access**: Disabled (if using Private Endpoint)
   - Or **Access restriction**: Configure IP restrictions
3. **Save**

---

## Step 11: Verify Deployment

### 11.1 Test Private Endpoint Connectivity

**From a machine on PA network (VPN/ExpressRoute):**

```bash
# Test DNS resolution
nslookup gcloud-api.pa.internal
nslookup gcloud-app.pa.internal

# Test HTTPS connectivity
curl -k https://gcloud-api.pa.internal/api/v1/health
curl -k https://gcloud-app.pa.internal
```

### 11.2 Verify Function Apps are Running

1. In Azure Portal, go to each Function App
2. Check **Functions** → Verify functions are listed
3. Check **Log stream** for any errors
4. Check **Metrics** for execution data

### 11.3 Test Application

1. Access frontend: `https://gcloud-app.pa.internal`
2. Verify authentication works
3. Test document generation
4. Test questionnaire functionality
5. Check Application Insights for errors

---

## Step 12: Configure Monitoring and Alerts

### 12.1 Set Up Alerts

1. Navigate to **Application Insights** → **Alerts**
2. Click **+ Create** → **Alert rule**
3. Configure:
   - **Signal type**: Metric
   - **Metric**: Failed requests
   - **Threshold**: > 5 in 5 minutes
4. Add action group for notifications
5. **Save**

### 12.2 Configure Cost Alerts

1. Navigate to **Cost Management + Billing** → **Budgets**
2. Click **+ Add**
3. Set budget for Function App executions
4. Configure alerts at 50%, 90%, 100%

---

## Troubleshooting

### Issue: Function App not accessible via Private Endpoint

**Solution:**
1. Verify Private Endpoint is created and approved
2. Check Private DNS Zone A record points to correct IP
3. Verify VNet link is configured
4. Test DNS resolution from VNet

### Issue: Storage Account access denied

**Solution:**
1. Verify Private Endpoint is approved
2. Check Function App has correct connection string
3. Verify managed identity has Storage Blob Data Contributor role

### Issue: Key Vault access denied

**Solution:**
1. Verify Private Endpoint is approved
2. Check Function App managed identity has Key Vault access policy
3. Verify secrets are correctly named

### Issue: Frontend not loading

**Solution:**
1. Verify React build files are in `static/` folder
2. Check Function App logs for errors
3. Verify API URL in frontend build is correct

---

## Cost Optimization Tips

1. **Use Consumption Plan**: Pay only for executions (zero cost when idle)
2. **Monitor Function Executions**: Set up alerts for unexpected usage
3. **Optimize Cold Starts**: Use Premium plan if needed (higher base cost)
4. **Review Storage Costs**: Use LRS for non-critical data
5. **Clean Up Old Blobs**: Implement lifecycle policies

---

## Security Checklist

- ✅ All services use Private Endpoints (no public access)
- ✅ Private DNS Zone configured and linked to VNet
- ✅ Managed identities used for Key Vault access
- ✅ Storage account access is private
- ✅ Function Apps have network restrictions
- ✅ Secrets stored in Key Vault (not in code)
- ✅ Application Insights monitoring enabled
- ✅ HTTPS only (enforced by ASE/Private Endpoint)

---

## Next Steps

1. **DNS Configuration**: Work with PA network team to configure DNS forwarding for `pa.internal` zone
2. **User Access**: Provide users with private URL: `https://gcloud-app.pa.internal`
3. **Documentation**: Update user documentation with new access method
4. **Monitoring**: Set up dashboards in Application Insights
5. **Backup Strategy**: Configure backup policies for Storage Account

---

## Quick Reference: Copy-Paste Commands

### Get Resource IDs

```bash
# Storage Account Connection String
az storage account show-connection-string \
  --name gcloudprodst \
  --resource-group gcloud-prod-rg \
  --query connectionString -o tsv

# Application Insights Instrumentation Key
az monitor app-insights component show \
  --app gcloud-prod-insights \
  --resource-group gcloud-prod-rg \
  --query instrumentationKey -o tsv

# Function App Managed Identity Principal ID
az functionapp identity show \
  --name gcloud-api-prod \
  --resource-group gcloud-prod-rg \
  --query principalId -o tsv
```

### Deploy Backend

```bash
cd /path/to/gcloud_automate
bash scripts/azure/deploy_api_function.sh
```

### Deploy Frontend

```bash
cd /path/to/gcloud_automate
bash scripts/azure/deploy_frontend.sh
```

---

## Support

For issues or questions:
1. Check Application Insights logs
2. Review Function App logs in Azure Portal
3. Verify network connectivity from PA network
4. Check Private Endpoint status

---

**Last Updated**: 2025-01-28
**Version**: 1.0
**Author**: G-Cloud Automation Team

