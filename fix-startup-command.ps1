# Quick fix: Set startup command to bypass entrypoint
param(
    [string]$WebAppName = "pa-gcloud15-web",
    [string]$ResourceGroup = "pa-gcloud15-rg"
)

Write-Host "Setting startup command to bypass entrypoint..." -ForegroundColor Cyan

# Set startup command to nginx directly
az webapp config set `
    --name $WebAppName `
    --resource-group $ResourceGroup `
    --startup-file "nginx -g 'daemon off;'" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Startup command set successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Restarting Web App..." -ForegroundColor Yellow
    az webapp restart --name $WebAppName --resource-group $ResourceGroup
    Write-Host "✓ Web App restarted. Wait 30 seconds, then test: https://$WebAppName.azurewebsites.net" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to set startup command" -ForegroundColor Red
}
