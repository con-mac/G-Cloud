# Check Logs in Azure Portal - Step by Step

## Issue
Function App is deployed but endpoints return 404. Log stream shows "Connected! (no logs)".

## Check Application Insights Logs

The Function App logs might be going to Application Insights instead of Log Stream.

### Step 1: Check Application Insights

1. Go to Azure Portal: https://portal.azure.com
2. Navigate to: **Application Insights** → `pa-gcloud15-api-insights` (or the name from your config)
3. Go to **"Logs"** in the left menu
4. Run this query:

```kusto
traces
| where timestamp > ago(1h)
| order by timestamp desc
| take 50
```

Or try:

```kusto
exceptions
| where timestamp > ago(1h)
| order by timestamp desc
```

### Step 2: Enable App Service Logs

1. Go to Function App: `pa-gcloud15-api`
2. Go to **"Settings"** → **"App Service logs"**
3. Enable:
   - **Application Logging (Filesystem)** → **On**
   - **Level** → **Verbose** (or at least **Information**)
   - Click **"Save"**
4. Go back to **"Log stream"** and wait a few seconds
5. Make a request to the API (refresh the test script)
6. You should now see logs

### Step 3: Check Function App Files

Verify the code was deployed correctly:

1. Go to Function App: `pa-gcloud15-api`
2. Go to **"Development Tools"** → **"Advanced Tools (Kudu)"** → **"Go"**
3. Navigate to: **"Debug console"** → **"CMD"**
4. Go to: `site/wwwroot/`
5. Check if these files exist:
   - `function_app/__init__.py`
   - `app/main.py`
   - `app/api/__init__.py`
   - `app/api/routes/proposals.py`

### Step 4: Check Function App Settings

1. Go to Function App: `pa-gcloud15-api`
2. Go to **"Configuration"** → **"Application settings"**
3. Check if these are set:
   - `FUNCTIONS_WORKER_RUNTIME` should be `python`
   - `FUNCTIONS_EXTENSION_VERSION` should be `~4` or `~3`
   - `AzureWebJobsStorage` should be set

### Step 5: Restart Function App

After enabling logs:

1. Go to Function App: `pa-gcloud15-api`
2. Go to **"Overview"**
3. Click **"Restart"**
4. Wait 30 seconds
5. Test endpoints again

## What to Look For

In the logs, look for:
- ✅ "API router imported successfully"
- ✅ "Proposals router imported successfully"
- ✅ "API router included successfully with prefix /api/v1"
- ❌ Any import errors
- ❌ Any exceptions during startup

## Quick Test

After enabling logs and restarting, run:

```powershell
.\pa-deployment\scripts\test-api-endpoints.ps1
```

Then check the logs again - you should see the requests coming in.

