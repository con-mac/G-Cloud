# Azure Subscription Setup Guide

## Issues Found & Fixes Applied

### 1. ✅ Resource Provider Registration
**Problem:** New Azure subscriptions need resource providers registered before creating resources.

**Fix Applied:**
- Created `register-resource-providers.ps1` script
- Automatically runs before deployment
- Registers: Microsoft.KeyVault, Microsoft.Web, Microsoft.Storage, Microsoft.ContainerRegistry, Microsoft.Insights, Microsoft.Network

**Manual Registration (if needed):**
```powershell
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.Network
```

### 2. ✅ Globally Unique Names
**Problem:** Storage Account, Key Vault, Function App, Web App, and ACR names must be globally unique.

**Fix Applied:**
- `deploy.ps1` now automatically adds a 6-character random suffix to all globally unique names
- Names are generated as: `baseName-randomSuffix`
- Example: `pa-gcloud15-api` → `pa-gcloud15-api-a3b2c1`

**What Changed:**
- Storage Account: `pagcloud15apist` → `pagcloud15apist-a3b2c1` (lowercase, alphanumeric)
- Key Vault: `pa-gcloud15-kv` → `pa-gcloud15-kv-a3b2c1`
- Function App: `pa-gcloud15-api` → `pa-gcloud15-api-a3b2c1`
- Web App: `pa-gcloud15-web` → `pa-gcloud15-web-a3b2c1`
- ACR: `pagcloud15acr` → `pagcloud15acr-a3b2c1` (lowercase, alphanumeric)

### 3. ✅ Better Error Handling
**Problem:** Scripts didn't handle resource provider registration errors well.

**Fix Applied:**
- Added provider registration checks before resource creation
- Better error messages for name conflicts
- Automatic retry logic for provider registration

## Pre-Deployment Setup (Manual Steps)

### Step 1: Register Resource Providers (if script fails)

Run this before deployment:

```powershell
# Register all required providers
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.Network

# Check registration status
az provider show --namespace Microsoft.KeyVault --query "registrationState" -o tsv
az provider show --namespace Microsoft.Web --query "registrationState" -o tsv
az provider show --namespace Microsoft.Storage --query "registrationState" -o tsv
```

**Wait time:** Registration can take 1-5 minutes. Check status with:
```powershell
az provider list --query "[?namespace=='Microsoft.KeyVault'].{Name:namespace, State:registrationState}" -o table
```

### Step 2: Check Subscription Quotas

Some Azure subscriptions have resource limits. Check your quotas:

```powershell
# Check App Service quota
az appservice plan list --query "[].{Name:name, Sku:sku.name, Capacity:sku.capacity}" -o table

# Check storage account quota (usually 250 per subscription)
az storage account list --query "length(@)" -o tsv
```

### Step 3: Verify Permissions

Ensure you have the right permissions:

```powershell
# Check your role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv) --output table

# You need: Owner OR (Contributor + User Access Administrator)
```

## Common Issues & Solutions

### Issue: "No available instances to satisfy this request"
**Cause:** App Service capacity issue in the selected region.

**Solutions:**
1. **Try a different region:**
   ```powershell
   # Use a different location
   # Try: eastus, westeurope, northeurope, uksouth
   ```

2. **Wait and retry:**
   - Azure is scaling capacity
   - Wait 10-15 minutes and try again

3. **Use a different resource group:**
   - Sometimes helps with capacity allocation

### Issue: "Storage account name already exists globally"
**Cause:** Name is taken by another subscription.

**Solution:**
- ✅ **FIXED:** Script now adds random suffix automatically
- If you see this error, the random suffix generation failed - report it

### Issue: "Resource provider not registered"
**Cause:** New subscription hasn't registered providers yet.

**Solution:**
- ✅ **FIXED:** Script now registers providers automatically
- If it fails, run manual registration (see Step 1 above)

### Issue: "Function App storage account not found"
**Cause:** Azure Functions needs a storage account, but creation failed.

**Solution:**
- The script should create this automatically
- If it fails, check storage account quota
- Try a different region

## Quick Pre-Deployment Checklist

Before running `deploy.ps1`:

- [ ] Run `az login` and verify subscription
- [ ] Check resource provider registration:
  ```powershell
  az provider list --query "[?namespace=='Microsoft.KeyVault' || namespace=='Microsoft.Web' || namespace=='Microsoft.Storage'].{Name:namespace, State:registrationState}" -o table
  ```
- [ ] If any show "NotRegistered", run:
  ```powershell
  .\scripts\register-resource-providers.ps1
  ```
- [ ] Verify you have appropriate permissions (Owner or Contributor)
- [ ] Have SharePoint site URL ready
- [ ] Be ready to accept random suffixes on resource names

## What the Script Does Now

1. ✅ **Registers resource providers** automatically (if not registered)
2. ✅ **Generates random suffixes** for all globally unique names
3. ✅ **Updates config file** with actual names (including suffixes)
4. ✅ **Better error handling** for common issues
5. ✅ **Checks name availability** before creating resources

## After Deployment

The actual resource names (with random suffixes) will be saved in:
- `config\deployment-config.env`
- Azure Portal (Resource Group → Resources)

You can check the actual names:
```powershell
# View config file
Get-Content config\deployment-config.env

# Or list resources
az resource list --resource-group <your-rg-name> --query "[].{Name:name, Type:type}" -o table
```

