# Fresh Start - Delete RG and Redeploy

## ✅ Safe to Delete Resource Group

**Yes, it's safe to delete the resource group!** Your App Registration is in Azure AD (not in the resource group), so it will persist and can be reused.

## Step 1: Delete the Resource Group

```powershell
# List your resource groups to confirm which one to delete
az group list --query "[].name" -o table

# Delete the deployment resource group (e.g., gcloud-azure-ps1-deploy-rg)
az group delete --name gcloud-azure-ps1-deploy-rg --yes --no-wait
```

**Note**: The ASE resource group (usually named something like `*-ase-rg` or `*-environment-rg`) should NOT be deleted.

## Step 2: Verify App Registration Still Exists (Optional)

```powershell
# List App Registrations
az ad app list --query "[].{DisplayName:displayName, AppId:appId}" -o table
```

Your App Registration will persist - it's in Azure AD, not the resource group.

## Step 3: Fresh Deployment

Once the RG is deleted, start fresh:

```powershell
# Pull latest changes
git pull origin main

# Run deployment
.\deploy.ps1
```

**When prompted:**
- **Resource Group**: Create new (or use existing if you want to reuse a name)
- **Function App**: Create new
- **Web App**: Create new
- **Storage Account**: Create new
- **Private DNS**: Create new or use existing
- **App Insights**: Create new or use existing
- **App Registration**: **Use existing** (your App Registration will be listed - select it)
- **Private Endpoints**: Choose **n** for now (test publicly first)

## Step 4: What Gets Created Fresh

- ✅ New Resource Group
- ✅ New Function App
- ✅ New Web App
- ✅ New Storage Account
- ✅ New Key Vault
- ✅ New Application Insights
- ✅ New Private DNS Zone (if you choose to create)
- ✅ New App Registration (or use existing)

## Step 5: What Persists

- ✅ **App Registration** - in Azure AD (will persist, can reuse)
- ✅ Any existing Private DNS Zones (if you choose to use existing)
- ✅ Any existing Storage Accounts (if you choose to use existing)

## Important Notes

1. **App Registration**: Your existing App Registration will persist in Azure AD. When the script asks, choose to **use existing** and select your App Registration from the list.

2. **App Registration Permissions**: If your App Registration already has the right permissions (Sites.ReadWrite.All, Files.ReadWrite.All, etc.), you're all set. The script will configure it to work with the new resources.

3. **Clean Slate**: This gives you a completely fresh deployment to test everything works, while reusing your App Registration.

## After Fresh Deployment

1. Test the app works publicly
2. Verify all features work
3. Then add private endpoints (run `.\deploy.ps1` again, choose **y**)

## Ready?

Just delete the RG and run `.\deploy.ps1` - it's that simple now!

