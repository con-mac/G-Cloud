# Quick fix for corrupted config file
# This script fixes the most common issues without prompts

$configPath = "config\deployment-config.env"

if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Reading config file..." -ForegroundColor Blue
$fileLines = Get-Content $configPath -Encoding UTF8
$fixed = $false
$newLines = @()

foreach ($line in $fileLines) {
    $originalLine = $line
    $line = $line.Trim()
    
    if ($line -and -not $line.StartsWith('#')) {
        $equalsIndex = $line.IndexOf('=')
        if ($equalsIndex -gt 0) {
            $key = $line.Substring(0, $equalsIndex).Trim()
            $value = $line.Substring($equalsIndex + 1).Trim()
            
            # Auto-fix known issues
            if ($key -eq "FUNCTION_APP_NAME" -and ($value.Length -lt 5 -or $value -eq "p")) {
                Write-Host "[FIX] FUNCTION_APP_NAME: '$value' -> 'pa-gcloud15-api'" -ForegroundColor Yellow
                $value = "pa-gcloud15-api"
                $fixed = $true
            }
            
            if ($key -eq "STORAGE_ACCOUNT_NAME" -and ($value.Length -lt 5 -or $value -eq "pst")) {
                # Try to get the actual storage account name from Azure
                Write-Host "[INFO] Attempting to find Storage Account name..." -ForegroundColor Blue
                $rg = $null
                foreach ($l in $fileLines) {
                    if ($l -match '^RESOURCE_GROUP=(.+)$') {
                        $rg = $matches[1].Trim()
                        break
                    }
                }
                
                if ($rg) {
                    $ErrorActionPreference = 'SilentlyContinue'
                    $storageAccounts = az storage account list --resource-group $rg --query "[].name" -o tsv 2>&1
                    $ErrorActionPreference = 'Stop'
                    
                    if ($LASTEXITCODE -eq 0 -and $storageAccounts) {
                        $firstSA = ($storageAccounts -split "`n")[0].Trim()
                        if ($firstSA) {
                            Write-Host "[FIX] STORAGE_ACCOUNT_NAME: '$value' -> '$firstSA'" -ForegroundColor Yellow
                            $value = $firstSA
                            $fixed = $true
                        }
                    }
                }
                
                if (-not $fixed -or $value -eq "pst") {
                    Write-Host "[WARNING] Could not auto-detect Storage Account. Please enter manually:" -ForegroundColor Yellow
                    $newValue = Read-Host "Enter Storage Account name"
                    if (-not [string]::IsNullOrWhiteSpace($newValue)) {
                        $value = $newValue
                        $fixed = $true
                    }
                }
            }
            
            $newLines += "$key=$value"
        } else {
            $newLines += $originalLine
        }
    } else {
        $newLines += $originalLine
    }
}

if ($fixed) {
    # Backup original
    $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $configPath $backupPath
    Write-Host "[INFO] Original config backed up to: $backupPath" -ForegroundColor Blue
    
    # Write fixed config
    $newLines | Set-Content $configPath -Encoding UTF8
    Write-Host "[SUCCESS] Config file fixed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] Fixed values:" -ForegroundColor Blue
    Get-Content $configPath | Select-String -Pattern "FUNCTION_APP_NAME|STORAGE_ACCOUNT_NAME" | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} else {
    Write-Host "[SUCCESS] Config file looks good - no fixes needed!" -ForegroundColor Green
}

