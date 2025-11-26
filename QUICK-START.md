# Quick Start - Deploy Frontend

## Your Next Step (Right Now)

You're ready to deploy! Run this command:

```powershell
.\scripts\deploy-frontend.ps1
```

This will:
1. Install npm dependencies
2. Build the frontend
3. Deploy to your Web App

**Expected time:** 5-10 minutes

---

## If You Haven't Run Main Deployment Yet

If you haven't run the main deployment script, do this first:

```powershell
.\deploy.ps1
```

Follow the prompts to create/select resources. This takes ~15 minutes.

Then run:

```powershell
.\scripts\deploy-frontend.ps1
```

---

## Verify It Worked

After deployment completes, open:

```
https://[YOUR-WEB-APP-NAME].azurewebsites.net
```

You should see the G-Cloud login page (not the default Azure page).

---

## Troubleshooting

**"package.json not found"** → Files are now copied, try again.

**"az not recognized"** → Restart PowerShell/VS Code after installing Azure CLI.

**Still see default Azure page** → Wait 2-3 minutes, clear browser cache.


