# Verify Function Registration in Azure Portal

## Issue
Getting default Azure Function App landing page instead of FastAPI app. This means the HTTP trigger function isn't registered.

## Check Function Registration

### Step 1: Check if Function is Registered

1. Go to Azure Portal: https://portal.azure.com
2. Navigate to: Function App → `pa-gcloud15-api`
3. Go to **"Functions"** in the left menu
4. **You should see a function listed** (likely named after the folder, e.g., `function_app` or similar)

**If NO functions are listed:**
- The function wasn't deployed correctly
- The `function_app` folder might not be in the right location
- The deployment might have excluded it

### Step 2: Check Deployed Files (Kudu)

1. Go to Function App → **"Development Tools"** → **"Advanced Tools (Kudu)"** → **"Go"**
2. Navigate to: **"Debug console"** → **"CMD"**
3. Go to: `site/wwwroot/`
4. Check if these exist:
   - `function_app/` folder
   - `function_app/__init__.py`
   - `function_app/function.json`
   - `host.json`
   - `app/` folder

**If `function_app` folder is missing:**
- The deployment didn't include it
- Need to redeploy with correct structure

### Step 3: Manual Function Registration (if needed)

If the function isn't registered but files exist:

1. Go to Function App → **"Functions"**
2. Click **"+ Create"** or **"Add"**
3. Choose **"HTTP trigger"**
4. Name it: `function_app` (or match your folder name)
5. Authorization level: **Anonymous**
6. Azure will detect the existing `function_app/function.json` and use it

### Step 4: Verify Function.json Location

The `function.json` must be in:
```
site/wwwroot/function_app/function.json
```

NOT in:
```
site/wwwroot/function.json  ❌
```

## Expected Structure

```
site/wwwroot/
├── host.json
├── function_app/
│   ├── __init__.py
│   └── function.json
├── app/
│   ├── main.py
│   └── ...
└── requirements.txt
```

## Quick Fix

If function isn't registered:

1. **Option 1: Redeploy** (ensures correct structure)
   ```powershell
   .\pa-deployment\scripts\deploy-functions.ps1
   ```

2. **Option 2: Manual Registration** (if files exist but function isn't registered)
   - Follow Step 3 above

3. **Option 3: Check Deployment Logs**
   - Function App → **"Deployment Center"** → **"Logs"**
   - Look for errors about function registration

## After Fixing

Once the function is registered:
1. Test the root endpoint again
2. You should get JSON response from FastAPI, not HTML landing page
3. Check logs for the diagnostic messages we added

