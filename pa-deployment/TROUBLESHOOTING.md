# Troubleshooting: Security Group Steps Not Appearing

If you don't see Steps 6.5 and 6.6 (Security Group Configuration) when running `deploy.ps1`, try these fixes:

## Quick Fixes

### 1. Verify File Was Updated
Check if the file has the security group code:
```powershell
Select-String -Path ".\pa-deployment\deploy.ps1" -Pattern "Step 6.5"
```

If it returns nothing, the file wasn't updated. Try:
```powershell
git pull origin main
git status
```

### 2. Clear PowerShell Cache
PowerShell may be caching the old script. Try:
```powershell
# Close and reopen PowerShell
# Or clear the command history
Clear-Host
```

### 3. Force Reload the Script
Instead of running `.\deploy.ps1`, try:
```powershell
# Remove the function from memory if it exists
Remove-Item function:\Start-Deployment -ErrorAction SilentlyContinue

# Run with full path
& ".\pa-deployment\deploy.ps1"
```

### 4. Check Line Endings (Windows vs Linux)
If you're on Windows and the file has Unix line endings, PowerShell might have issues:
```powershell
# Check line endings
Get-Content ".\pa-deployment\deploy.ps1" -Raw | Select-String -Pattern "`r`n" | Measure-Object

# If needed, convert to Windows line endings
(Get-Content ".\pa-deployment\deploy.ps1" -Raw) -replace "`n", "`r`n" | Set-Content ".\pa-deployment\deploy.ps1" -NoNewline
```

### 5. Verify You're Running the Right File
Make sure you're in the correct directory:
```powershell
Get-Location
# Should be: C:\Users\conor\Documents\Projects\G-Cloud

# Check if file exists
Test-Path ".\pa-deployment\deploy.ps1"
```

### 6. Manual Check
Open the file and search for "Step 6.5" - it should be around line 686:
```powershell
Get-Content ".\pa-deployment\deploy.ps1" | Select-String -Pattern "Step 6.5" -Context 2
```

## Expected Flow

After Step 6 (App Registration), you should see:
- **Step 6.5: Admin Security Group Configuration**
- **Step 6.6: Employee Security Group Configuration (Optional)**
- **Step 7: Custom Domain Configuration**

If Step 6.5 doesn't appear, the script is skipping that section.

## If Still Not Working

1. **Check git status** - Make sure you're on the latest commit:
   ```powershell
   git log --oneline -1 -- pa-deployment/deploy.ps1
   ```
   Should show: `7ee194d Add employee security group handler to deploy.ps1 (Step 6.6)`

2. **Re-download the file**:
   ```powershell
   git checkout HEAD -- pa-deployment/deploy.ps1
   ```

3. **Check for syntax errors**:
   ```powershell
   $errors = $null
   $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content ".\pa-deployment\deploy.ps1" -Raw), [ref]$errors)
   $errors
   ```

