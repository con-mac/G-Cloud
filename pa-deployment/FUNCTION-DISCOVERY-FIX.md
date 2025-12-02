# Function Discovery Fix

## Issue
Function App is deployed but no functions are listed in Azure Portal. The function_app folder exists but isn't being discovered.

## Root Cause
Azure Functions needs to discover functions after deployment. Sometimes a restart is required, or the function structure needs to be verified.

## Automated Fix (No Manual Intervention)

The deployment script has been updated to:
1. ✅ Verify `function_app` files are included in deployment
2. ✅ Restart Function App after deployment to trigger function discovery
3. ✅ Log which function files are being deployed

## Next Steps

### Step 1: Redeploy with Updated Script

```powershell
.\pa-deployment\scripts\deploy-functions.ps1
```

The script will now:
- Verify function_app files are included
- Deploy the code
- **Automatically restart the Function App** to trigger function discovery
- Wait 30-60 seconds for discovery

### Step 2: Verify Function is Registered

After deployment completes:

1. Go to Azure Portal: Function App → `pa-gcloud15-api` → **"Functions"**
2. You should now see a function listed (e.g., `function_app`)
3. If still not listed, wait another 30 seconds and refresh

### Step 3: Test the Endpoint

Once the function is listed:

```powershell
.\pa-deployment\scripts\test-api-endpoints.ps1
```

You should now get JSON responses from FastAPI, not the HTML landing page.

## If Function Still Not Discovered

If after redeployment and restart the function still isn't listed:

1. **Check Kudu Console:**
   - Function App → Development Tools → Advanced Tools (Kudu) → Go
   - Debug console → CMD → `site/wwwroot/`
   - Verify `function_app/` folder exists with `__init__.py` and `function.json`

2. **Check Function App Settings:**
   - Configuration → Application settings
   - Verify `FUNCTIONS_WORKER_RUNTIME` = `python`
   - Verify `FUNCTIONS_EXTENSION_VERSION` = `~4` or `~3`

3. **Force Sync (if needed):**
   ```powershell
   az functionapp restart --name pa-gcloud15-api --resource-group pa-gcloud15-rg
   ```

## Expected Result

After successful deployment and restart:
- Function appears in "Functions" list
- Root endpoint (`/`) returns FastAPI JSON response
- `/api/v1/` endpoints work correctly
- Diagnostic logs appear in Log stream

