# Quick Fix Config File

If your config file has wrong values, use these commands:

## Fix Config File Automatically

```powershell
.\pa-deployment\scripts\fix-config-now.ps1
```

This script:
- Detects your actual Function App name from Azure
- Updates `FUNCTION_APP_NAME` in config file
- Shows next steps

## Manual Override (Before Deployment)

Edit `pa-deployment\config\deployment-config.env` and change any values:

```env
FUNCTION_APP_NAME=pa-gcloud15-api-14sxir
WEB_APP_NAME=pa-gcloud15-web-14sxir
RESOURCE_GROUP=pa-gcloud15-rg
```

## Complete Fix Commands (Copy-Paste Ready)

**1. Fix config file:**
```powershell
.\pa-deployment\scripts\fix-config-now.ps1
```

**2. Rebuild Docker image with correct API URL:**
```powershell
.\pa-deployment\scripts\build-and-push-images.ps1
```

**3. Redeploy frontend:**
```powershell
.\pa-deployment\scripts\deploy-frontend.ps1
```

**4. Restart Web App:**
```powershell
az webapp restart --name pa-gcloud15-web-14sxir --resource-group pa-gcloud15-rg
```

**5. Configure CORS (if not done):**
- Azure Portal → Function App → `pa-gcloud15-api-14sxir`
- Settings → CORS
- Add: `https://pa-gcloud15-web-14sxir.azurewebsites.net`
- Enable "Access-Control-Allow-Credentials"
- Save and restart Function App

## Override Config During Deployment

When running `deploy.ps1`, you can override any value at the prompts. The script will:
1. Show existing resources
2. Let you select existing or create new
3. Save your choices to config file

To start fresh, just delete `pa-deployment\config\deployment-config.env` and run `deploy.ps1` again.

