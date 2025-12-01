# Update SSO app settings with real values
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"

# Get actual values
$tenantId = az account show --query tenantId -o tsv
$appId = az ad app list --display-name "pa-gcloud15-app" --query "[0].appId" -o tsv

Write-Host "Updating SSO settings..." -ForegroundColor Cyan
Write-Host "Tenant ID: $tenantId" -ForegroundColor Yellow
Write-Host "Client ID: $appId" -ForegroundColor Yellow

# Update app settings
az webapp config appsettings set `
    --name $WebAppName `
    --resource-group $ResourceGroup `
    --settings `
        "VITE_AZURE_AD_TENANT_ID=$tenantId" `
        "VITE_AZURE_AD_CLIENT_ID=$appId" `
        "VITE_AZURE_AD_REDIRECT_URI=https://${WebAppName}.azurewebsites.net" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SSO settings updated!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now rebuild the image (with entrypoint script):" -ForegroundColor Yellow
    Write-Host "  git pull origin main" -ForegroundColor White
    Write-Host "  .\scripts\build-and-push-images.ps1" -ForegroundColor White
    Write-Host "  .\scripts\deploy-frontend.ps1" -ForegroundColor White
} else {
    Write-Host "✗ Failed to update settings" -ForegroundColor Red
}
