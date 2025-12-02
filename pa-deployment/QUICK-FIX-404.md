# Quick Fix for 404 Errors

## Issue
All `/api/v1/` endpoints return 404, but root `/` works.

## Solution: Redeploy Backend

The backend has been updated with logging to diagnose the issue. Redeploy it:

### Step 1: Navigate to Project Root

You need to be in the project root (not the `backend` directory):

```powershell
# If you're in backend directory, go up:
cd ..

# Or from anywhere, navigate to project root:
cd C:\Users\conor\Documents\Projects\G-Cloud
```

### Step 2: Redeploy Backend

```powershell
.\pa-deployment\scripts\deploy-functions.ps1
```

### Step 3: Check Logs

After deployment, check Function App logs in Azure Portal:

1. Go to: https://portal.azure.com
2. Navigate to: Function App → `pa-gcloud15-api`
3. Go to **"Log stream"** or **"Logs"**
4. Look for:
   - "API router imported successfully"
   - "Proposals router imported successfully" (or warnings)
   - "API router included successfully with prefix /api/v1"
   - Any import errors

### Step 4: Test Again

After deployment completes (2-3 minutes), test the endpoints:

```powershell
.\pa-deployment\scripts\test-api-endpoints.ps1
```

## What the Logs Will Show

The new logging will reveal:
- ✅ Which routers are loading successfully
- ❌ Which routers are failing to import
- 📊 How many routes are registered
- 🔍 Any import errors preventing API router from loading

## Expected Log Output

You should see logs like:
```
INFO: API router imported successfully
INFO: API router has X routes
INFO: Proposals router imported successfully
INFO: Proposals router included
INFO: API router included successfully with prefix /api/v1
```

If you see errors, they will tell us exactly what's failing.

