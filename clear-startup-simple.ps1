# SIMPLER: Use az webapp config set with generic-configurations
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"

Write-Host "Clearing startup command..." -ForegroundColor Cyan

# Use generic-configurations to set appCommandLine to empty string
az webapp config set `
    --name $WebAppName `
    --resource-group $ResourceGroup `
    --generic-configurations '{"appCommandLine": ""}'

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Startup command cleared" -ForegroundColor Green
    Write-Host "Restarting app..." -ForegroundColor Yellow
    az webapp restart --name $WebAppName --resource-group $ResourceGroup
    Write-Host "✓ Done!" -ForegroundColor Green
} else {
    Write-Host "✗ Failed. Try the REST API method instead." -ForegroundColor Red
}
