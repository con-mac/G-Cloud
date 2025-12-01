# Quick script to check container logs
param(
    [string]$WebAppName = "pa-gcloud15-web",
    [string]$ResourceGroup = "pa-gcloud15-rg"
)

Write-Host "Checking logs for $WebAppName..." -ForegroundColor Cyan
Write-Host ""

# Method 1: Recent logs via Azure CLI
Write-Host "=== Recent Container Logs ===" -ForegroundColor Yellow
az webapp log tail --name $WebAppName --resource-group $ResourceGroup 2>&1 | Select-Object -First 50

Write-Host ""
Write-Host "=== Alternative: Check via SSH ===" -ForegroundColor Yellow
Write-Host "Run: az webapp ssh --name $WebAppName --resource-group $ResourceGroup"
Write-Host "Then inside container, run:"
Write-Host "  ls -la /usr/share/nginx/html/"
Write-Host "  cat /entrypoint.sh"
Write-Host "  ps aux"
