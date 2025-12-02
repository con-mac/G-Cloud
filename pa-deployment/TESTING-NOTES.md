# Testing Notes for Personal Azure Deployment

## Important Context

**You are currently deploying in your personal Azure AD tenant.** When PA's deployment team runs the scripts in PA's Azure AD tenant, the App Registration will be created in PA's tenant, and PA users will be able to authenticate.

## Current Issues & Solutions

### 1. Email Format Mismatch (FIXED)

**Issue:** When logging in with `conor.macklin1986@gmail.com`, the frontend was converting it to `conor.macklin@paconsulting.com` based on your account name.

**Fix Applied:** The email formatting now:
- Uses actual email for external domains (Gmail, etc.)
- Only converts to `firstName.LastName@paconsulting.com` for PA Consulting domains
- This allows testing with your personal Gmail account

**Result:** API calls will now use `conor.macklin1986@gmail.com` instead of `conor.macklin@paconsulting.com`.

### 2. CORS Error (NEEDS FIX)

**Issue:** The CORS setting update returned null values, meaning it didn't apply correctly.

**Solution:** Run this PowerShell script to check and fix:

```powershell
.\pa-deployment\scripts\fix-cors.ps1
```

Or manually:

```powershell
# Check current setting
az functionapp config appsettings list `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --query "[?name=='CORS_ORIGINS']"

# Set CORS (if missing or null)
az functionapp config appsettings set `
    --name pa-gcloud15-api `
    --resource-group pa-gcloud15-rg `
    --settings "CORS_ORIGINS=https://pa-gcloud15-web.azurewebsites.net,http://localhost:3000,http://localhost:5173"

# Restart Function App
az functionapp restart --name pa-gcloud15-api --resource-group pa-gcloud15-rg
```

### 3. PA Laptop Access Issue

**Issue:** When trying to access from PA laptop, you get: "selected user doesn't exist in 'Default Directory' and cannot access the app, add them as an external user."

**Explanation:** This is expected because:
- The App Registration is in your **personal Azure AD tenant**
- Your PA laptop is trying to authenticate with **PA's Azure AD tenant**
- Your Gmail account (`conor.macklin1986@gmail.com`) is not in PA's Azure AD

**Solution:** This will be resolved when PA's deployment team:
1. Runs `deploy.ps1` in PA's Azure AD tenant
2. Creates a new App Registration in PA's tenant
3. PA users will then authenticate with their PA accounts (`@paconsulting.com`)

**For now:** You can only test from your personal laptop/device where you're logged into your personal Azure AD.

## Next Steps

1. **Fix CORS:**
   ```powershell
   .\pa-deployment\scripts\fix-cors.ps1
   ```

2. **Rebuild frontend** (to get email formatting fix):
   ```powershell
   .\pa-deployment\scripts\build-and-push-images.ps1
   .\pa-deployment\scripts\deploy-frontend.ps1
   ```

3. **Test again** - The email should now match your login email, and CORS should work.

## For PA Deployment Team

When deploying to PA's Azure AD:
- The App Registration will be created in PA's tenant
- PA users with `@paconsulting.com` emails will authenticate normally
- Email formatting will convert to `firstName.LastName@paconsulting.com` format
- No external user invitations needed

