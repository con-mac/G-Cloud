# Fresh Start - Delete RG and Redeploy

## ✅ Safe to Delete Resource Group

**Yes, it's safe to delete the resource group!** The App Service Environment (ASE) is in a separate resource group, so it won't be affected.

## Step 1: Delete the Resource Group

```powershell
# List your resource groups to confirm which one to delete
az group list --query "[].name" -o table

# Delete the deployment resource group (e.g., gcloud-azure-ps1-deploy-rg)
az group delete --name gcloud-azure-ps1-deploy-rg --yes --no-wait
```

**Note**: The ASE resource group (usually named something like `*-ase-rg` or `*-environment-rg`) should NOT be deleted.

## Step 2: Verify ASE Still Exists

```powershell
# List App Service Environments
az appservice ase list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o table
```

Make sure your ASE is still there and note which resource group it's in.

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

- ✅ App Service Environment (ASE) - in separate RG
- ✅ Any existing App Registrations (if you choose to use existing)
- ✅ Any existing Private DNS Zones (if you choose to use existing)
- ✅ Any existing Storage Accounts (if you choose to use existing)

## Important Notes

1. **ASE**: If your Web App/Function App needs to use the ASE, you'll need to:
   - Create them in the ASE's resource group, OR
   - Configure them to use the ASE after creation
   - The deployment script will create them in the new RG - you may need to move them or recreate in the ASE RG

2. **App Registration**: If you have an existing one, you can reuse it (the script will ask)

3. **Clean Slate**: This gives you a completely fresh deployment to test everything works

## After Fresh Deployment

1. Test the app works publicly
2. Verify all features work
3. Then add private endpoints (run `.\deploy.ps1` again, choose **y**)

## Ready?

Just delete the RG and run `.\deploy.ps1` - it's that simple now!

