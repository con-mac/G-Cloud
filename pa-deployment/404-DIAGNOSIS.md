# 404 Error Diagnosis - Proposals Endpoint

## Issue
Getting 404 error when accessing `/api/v1/proposals/` even though CORS is now working.

## Possible Causes

1. **Proposals router not loading** - The `proposals` module might be failing to import
2. **Route not registered** - The router might not be included in the API router
3. **Function App startup error** - There might be an error preventing routes from being registered

## Diagnosis Steps

### Step 1: Test Other Endpoints

Run this script to test all API endpoints:

```powershell
.\pa-deployment\scripts\test-api-endpoints.ps1
```

This will test:
- `/` - Root endpoint
- `/health` - Health check
- `/api/v1/` - API root
- `/api/v1/proposals/` - Proposals endpoint (the one failing)
- `/docs` - API documentation

### Step 2: Check Function App Logs

1. Go to Azure Portal: https://portal.azure.com
2. Navigate to Function App: `pa-gcloud15-api`
3. Go to **"Log stream"** or **"Logs"** in the left menu
4. Look for:
   - Import errors related to `proposals`
   - Startup errors
   - Route registration messages

### Step 3: Check API Documentation

Try accessing the API docs to see what routes are registered:

```
https://pa-gcloud15-api.azurewebsites.net/docs
```

If `/docs` works, you can see all registered routes. If `/docs` also returns 404, the FastAPI app might not be starting correctly.

## Common Fixes

### Fix 1: Redeploy Backend

The proposals router might not be in the deployed code:

```powershell
.\pa-deployment\scripts\deploy-functions.ps1
```

### Fix 2: Check Import Errors

If the proposals module fails to import, check:
- Are all dependencies installed? (`requirements.txt`)
- Is the SharePoint service importable?
- Are there any syntax errors in `backend/app/api/routes/proposals.py`?

### Fix 3: Verify Route Registration

The route should be:
- Defined in: `backend/app/api/routes/proposals.py` as `@router.get("/")`
- Included in: `backend/app/api/__init__.py` as `api_router.include_router(proposals.router, prefix="/proposals")`
- Mounted in: `backend/app/main.py` as `app.include_router(api_router, prefix="/api/v1")`

Final route should be: `/api/v1/proposals/`

## Next Steps

1. Run `test-api-endpoints.ps1` to see which endpoints work
2. Check Function App logs for errors
3. Try accessing `/docs` to see registered routes
4. If needed, redeploy the backend

