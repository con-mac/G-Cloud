# Clear startup command - use null/empty value
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"

Write-Host "Checking current startup command..." -ForegroundColor Cyan
$current = az webapp config show --name $WebAppName --resource-group $ResourceGroup --query "linuxFxVersion" -o tsv
Write-Host "Current: $current" -ForegroundColor Yellow

Write-Host ""
Write-Host "Note: For container-based apps, startup-file is in General Settings" -ForegroundColor Yellow
Write-Host "You can clear it manually in Azure Portal:" -ForegroundColor Yellow
Write-Host "  App Services -> pa-gcloud15-web -> Configuration -> General Settings -> Startup Command" -ForegroundColor Cyan
Write-Host "  Set it to empty/blank and Save" -ForegroundColor Cyan

Write-Host ""
Write-Host "Or continue with rebuild - the new Dockerfile should work without startup override" -ForegroundColor Green
