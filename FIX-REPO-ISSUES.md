# Fix Repository and Path Issues

## Issues Found

1. **Wrong Repository**: You're pulling from the PUBLIC repo (`G-Cloud`) instead of the PRIVATE repo (`g-cloud-v15`)
2. **Invalid File Paths**: Windows alternate data stream files with colons in names
3. **Script Path**: Script can't find config file due to path resolution

## Fixes Applied

### 1. Removed Problematic Files
- Removed `Developer_Guides/G-Cloud_Proposal_Automation_Application_AWS.docx:Zone.Identifier`
- Removed `docs/RM1557.15-G-Cloud-question-export.xlsx:Zone.Identifier`
- Added `*:Zone.Identifier` to `.gitignore` to prevent future issues

### 2. Improved Script Path Resolution
- `verify-msal-config.ps1` now tries multiple config file locations
- Works from project root or pa-deployment directory

### 3. Repository Configuration

**IMPORTANT**: Make sure you're using the PRIVATE repository!

**Check your current remote:**
```powershell
git remote -v
```

**Should show:**
```
origin  https://github.com/con-mac/g-cloud-v15.git (fetch)
origin  https://github.com/con-mac/g-cloud-v15.git (push)
```

**If it shows `G-Cloud` instead, fix it:**
```powershell
git remote set-url origin https://github.com/con-mac/g-cloud-v15.git
git remote add public https://github.com/con-mac/G-Cloud.git
```

## Next Steps

1. **Pull from the correct repo:**
   ```powershell
   git pull origin main
   ```

2. **Run the verification script from project root:**
   ```powershell
   # Make sure you're in the project root (C:\Users\conor\Documents\Projects\G-Cloud)
   .\pa-deployment\scripts\verify-msal-config.ps1
   ```

3. **If script still can't find config, run deploy.ps1 first:**
   ```powershell
   .\pa-deployment\deploy.ps1
   ```

## Windows-Specific Notes

- Windows creates `:Zone.Identifier` alternate data streams for downloaded files
- These files have colons in their names which Git can't handle on Windows
- They're now ignored by `.gitignore`
- If you see similar errors, check for files with colons in their names

