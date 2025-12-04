# Pre-Deployment Checklist

**Before running `deploy.ps1`**, gather the following information and verify prerequisites.

## ✅ Prerequisites

### 1. Azure Account & Access
- [ ] **Azure subscription** active and accessible
- [ ] **Azure CLI installed** (`az --version` should work)
- [ ] **Logged in to Azure CLI** (`az login`)
- [ ] **Correct subscription selected** (`az account show` to verify)
- [ ] **Appropriate permissions** (Owner or Contributor + User Access Administrator roles)

**Verify:**
```powershell
az account show
az account list  # See all available subscriptions
az account set --subscription "<subscription-id>"  # If needed
```

### 2. Microsoft 365 / SharePoint
- [ ] **SharePoint site exists** and you have access
- [ ] **SharePoint site URL** (full URL, e.g., `https://yourtenant.sharepoint.com/sites/YourSite`)
- [ ] **SharePoint site ID** (optional - can be auto-detected, but having it ready is better)

**How to get SharePoint Site ID:**
1. Go to your SharePoint site
2. Open browser console (F12)
3. Run: `_spPageContextInfo.siteId`
4. Copy the GUID (without curly braces)

**Or use this PowerShell:**
```powershell
# You'll need to authenticate to SharePoint first
# The deployment script can auto-detect it from the URL
```

### 3. Naming Conventions
Decide on naming for your resources (all must be globally unique where applicable):

- [ ] **Resource Group name** (e.g., `pa-gcloud15-rg`)
- [ ] **Function App name** (backend API, e.g., `pa-gcloud15-api`) - must be globally unique
- [ ] **Web App name** (frontend, e.g., `pa-gcloud15-web`) - must be globally unique
- [ ] **Key Vault name** (e.g., `pa-gcloud15-kv`) - must be globally unique
- [ ] **App Registration name** (e.g., `pa-gcloud15-app`)
- [ ] **Storage Account name** (if creating new, e.g., `pagcloud15st`) - must be globally unique, lowercase, alphanumeric only
- [ ] **ACR name** (Container Registry, e.g., `pagcloud15acr`) - must be globally unique, lowercase, alphanumeric only
- [ ] **Application Insights name** (e.g., `pa-gcloud15-api-insights`)
- [ ] **Custom domain** (for private DNS, e.g., `PA-G-Cloud15`)

**Naming Rules:**
- Function App: 2-60 chars, alphanumeric and hyphens
- Web App: 2-60 chars, alphanumeric and hyphens
- Key Vault: 3-24 chars, alphanumeric and hyphens, globally unique
- Storage Account: 3-24 chars, lowercase, alphanumeric only, globally unique
- ACR: 5-50 chars, alphanumeric only, globally unique

### 4. Security Groups (Optional but Recommended)
- [ ] **Admin Security Group name** (e.g., `G-Cloud-Admin-Users`)
  - If it doesn't exist, the script can create it
  - If it exists, have the name ready
- [ ] **Employee Security Group name** (optional, e.g., `G-Cloud-Employees`)
  - If it doesn't exist, the script can create it

### 5. Network Configuration (If Using Private Endpoints)
- [ ] **VNet name** (if using existing, e.g., `pa-gcloud15-vnet`)
- [ ] **Subnet name** (e.g., `functions-subnet`)
- [ ] **Private DNS Zone name** (if using existing, default: `privatelink.azurewebsites.net`)

**Note:** You can skip private endpoints initially and add them later for testing.

### 6. Location/Region
- [ ] **Azure region** (e.g., `uksouth`, `eastus`, `westeurope`)
  - Should match your M365 tenant region if possible
  - Common: `uksouth`, `eastus`, `westeurope`, `northeurope`

## 📋 Information to Have Ready

### During Deployment, You'll Be Asked For:

1. **Resource Group**
   - Create new or use existing
   - Name

2. **Function App**
   - Name (must be globally unique)

3. **Web App**
   - Name (must be globally unique)

4. **Key Vault**
   - Create new or use existing
   - Name (must be globally unique)

5. **SharePoint Configuration**
   - Site URL (full URL)
   - Site ID (optional - can auto-detect)

6. **App Registration**
   - Name
   - Will be created automatically

7. **Security Groups**
   - Admin group name (create or use existing)
   - Employee group name (optional)

8. **Storage Account** (if needed)
   - Create new or skip
   - Name (must be globally unique, lowercase)

9. **ACR** (Container Registry)
   - Create new or use existing
   - Name (must be globally unique, lowercase)

10. **Application Insights**
    - Create new or use existing
    - Name

11. **Private Endpoints**
    - Configure now or later (recommend "later" for first deployment)

## 🔍 Pre-Deployment Verification

Run these commands to verify everything is ready:

```powershell
# 1. Verify Azure CLI is installed and logged in
az --version
az account show

# 2. List available subscriptions (if you have multiple)
az account list --output table

# 3. Set correct subscription (if needed)
az account set --subscription "<subscription-id-or-name>"

# 4. Verify you have permissions (should show your account)
az role assignment list --assignee $(az account show --query user.name -o tsv) --output table

# 5. Test Azure CLI connectivity
az group list --output table
```

## 🚨 Common Issues to Avoid

### 1. Name Conflicts
- **Problem:** Resource names must be globally unique
- **Solution:** Use unique prefixes (e.g., include your initials, date, or tenant name)

### 2. Subscription Limits
- **Problem:** Some Azure subscriptions have resource limits
- **Solution:** Check your subscription quota before deployment

### 3. SharePoint Site Access
- **Problem:** Can't access SharePoint site or get Site ID
- **Solution:** Ensure you're logged in with an account that has SharePoint access

### 4. Permissions
- **Problem:** Insufficient permissions to create resources
- **Solution:** Ensure you have Owner or Contributor + User Access Administrator roles

## 📝 Quick Reference: Minimum Required Info

**Absolute minimum to start deployment:**
1. ✅ Azure CLI installed and logged in
2. ✅ Subscription ID or name
3. ✅ Resource names (Function App, Web App, Key Vault)
4. ✅ SharePoint site URL
5. ✅ Location/region

**Everything else can be:**
- Auto-detected (SharePoint Site ID)
- Created automatically (App Registration, Security Groups)
- Skipped initially (Private Endpoints, Storage Account, ACR)

## 🎯 Recommended: Pre-Deployment Test

Before running the full deployment, test that you can create a simple resource:

```powershell
# Test resource creation (will be deleted immediately)
$testRG = "test-gcloud-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
az group create --name $testRG --location uksouth
az group delete --name $testRG --yes --no-wait
```

If this works, you're ready for deployment!

## 📞 If Something Goes Wrong

1. **Check Azure Portal** - Verify resources were created
2. **Check logs** - Deployment script shows detailed output
3. **Run fix scripts** - Located in `pa-deployment/scripts/`
4. **Manual steps** - All documented in post-deployment steps

## ✅ Final Checklist Before Running deploy.ps1

- [ ] Azure CLI installed (`az --version` works)
- [ ] Logged in to Azure (`az account show` works)
- [ ] Correct subscription selected
- [ ] Have SharePoint site URL ready
- [ ] Decided on resource names (Function App, Web App, Key Vault)
- [ ] Decided on location/region
- [ ] Have admin security group name (or will create new)
- [ ] Ready to answer interactive prompts (or have all values ready)

**You're ready! Run:**
```powershell
cd pa-deployment
.\deploy.ps1
```

