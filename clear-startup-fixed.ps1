# Clear startup command via REST API (FIXED VERSION)
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"
$subId = "122958f0-5813-402e-87a7-50161442eab9"

Write-Host "Clearing startup command..." -ForegroundColor Cyan

# Get access token
$token = az account get-access-token --query accessToken -o tsv

# Get current config
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/web?api-version=2022-03-01"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$config = az rest --method GET --uri $uri --headers $headers | ConvertFrom-Json

# Remove appCommandLine
$config.properties.appCommandLine = ""

# Update - need to convert headers properly
$body = $config | ConvertTo-Json -Depth 10
$body | Out-File -FilePath "$env:TEMP\webconfig.json" -Encoding utf8

az rest --method PUT --uri $uri --headers $headers --body "@$env:TEMP\webconfig.json"

Write-Host "✓ Startup command cleared" -ForegroundColor Green

# Restart
Write-Host "Restarting app..." -ForegroundColor Yellow
az webapp restart --name $WebAppName --resource-group $ResourceGroup

Write-Host "✓ Done! Now rebuild the image:" -ForegroundColor Green
Write-Host "  git pull origin main" -ForegroundColor White
Write-Host "  .\scripts\build-and-push-images.ps1" -ForegroundColor White
Write-Host "  .\scripts\deploy-frontend.ps1" -ForegroundColor White
