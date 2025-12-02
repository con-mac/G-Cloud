# Fix CORS via Azure Portal

## Quick Fix in Azure Portal

Azure Function Apps have **built-in CORS settings** that can override your application's CORS middleware. You need to configure CORS at the Function App level.

### Steps:

1. **Go to Azure Portal:**
   - Navigate to: https://portal.azure.com
   - Find your Function App: `pa-gcloud15-api`
   - Resource Group: `pa-gcloud15-rg`

2. **Open CORS Settings:**
   - In the left menu, go to **"API"** → **"CORS"**
   - OR search for "CORS" in the search bar at the top

3. **Configure Allowed Origins:**
   - Click **"Add"** or **"+"** to add allowed origins
   - Add these origins (one at a time or comma-separated):
     - `https://pa-gcloud15-web.azurewebsites.net`
     - `http://localhost:3000`
     - `http://localhost:5173`
   
   - **IMPORTANT:** Make sure **"Enable Access-Control-Allow-Credentials"** is checked/ON
   - **IMPORTANT:** Uncheck **"Enable Access-Control-Allow-Credentials"** if you see it, OR ensure it matches your FastAPI CORS config

4. **Save:**
   - Click **"Save"** at the top
   - Wait for the save to complete

5. **Restart Function App:**
   - Go to **"Overview"** in the left menu
   - Click **"Restart"** button
   - Wait 30-60 seconds

6. **Test Again:**
   - Refresh your frontend page
   - CORS should now work!

## Alternative: Via Azure CLI

If you prefer command line:

```powershell
# Enable CORS and add allowed origins
az functionapp cors add `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --allowed-origins "https://pa-gcloud15-web.azurewebsites.net" "http://localhost:3000" "http://localhost:5173"

# Verify CORS settings
az functionapp cors show `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg

# Restart Function App
az functionapp restart `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg
```

## Why This Is Needed

Azure Function Apps have **two layers of CORS**:
1. **Function App level CORS** (configured in Portal/CLI) - This is what Azure enforces first
2. **Application level CORS** (FastAPI middleware) - This only works if Function App CORS allows it

If Function App CORS is blocking, FastAPI's CORS middleware never gets a chance to respond.

## After Fixing

Once CORS is configured at the Function App level, your FastAPI CORS middleware will also work, providing double protection.

