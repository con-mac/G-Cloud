# Fix deployment config file
# This script validates and fixes common issues in deployment-config.env

$configPath = "config\deployment-config.env"

if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] Config file not found: $configPath" -ForegroundColor Red
    Write-Host "Please run deploy.ps1 first to create the config file." -ForegroundColor Yellow
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
            
            # Fix common truncated values
            if ($key -eq "FUNCTION_APP_NAME" -and ($value.Length -lt 5 -or $value -eq "p")) {
                Write-Host "[FIX] FUNCTION_APP_NAME is truncated: '$value'" -ForegroundColor Yellow
                $value = Read-Host "Enter correct Function App name [pa-gcloud15-api]"
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $value = "pa-gcloud15-api"
                }
                $fixed = $true
            }
            
            if ($key -eq "RESOURCE_GROUP" -and -not $value.EndsWith("-rg")) {
                Write-Host "[FIX] RESOURCE_GROUP should end with '-rg': '$value'" -ForegroundColor Yellow
                if (-not $value.EndsWith("rg")) {
                    $value = Read-Host "Enter correct Resource Group name"
                    if ([string]::IsNullOrWhiteSpace($value)) {
                        Write-Host "[ERROR] Resource Group name is required" -ForegroundColor Red
                        exit 1
                    }
                }
                $fixed = $true
            }
            
            if ($key -eq "STORAGE_ACCOUNT_NAME" -and $value.Length -lt 5) {
                Write-Host "[FIX] STORAGE_ACCOUNT_NAME appears truncated: '$value'" -ForegroundColor Yellow
                $value = Read-Host "Enter correct Storage Account name"
                if ([string]::IsNullOrWhiteSpace($value)) {
                    Write-Host "[WARNING] Storage Account name left empty" -ForegroundColor Yellow
                }
                $fixed = $true
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
    $backupPath = "$configPath.backup"
    Copy-Item $configPath $backupPath
    Write-Host "[INFO] Original config backed up to: $backupPath" -ForegroundColor Blue
    
    # Write fixed config
    $newLines | Set-Content $configPath -Encoding UTF8
    Write-Host "[SUCCESS] Config file fixed!" -ForegroundColor Green
    Write-Host "[INFO] Please review the fixed config:" -ForegroundColor Blue
    Get-Content $configPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Host "[SUCCESS] Config file looks good!" -ForegroundColor Green
}

