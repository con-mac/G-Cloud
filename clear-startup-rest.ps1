# Clear startup command using REST API
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"

# Get subscription ID
$subId = az account show --query id -o tsv

Write-Host "Clearing startup command via REST API..." -ForegroundColor Cyan

# Get access token
$token = az account get-access-token --query accessToken -o tsv

# API endpoint
$uri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/web?api-version=2022-03-01"

# Get current config
$current = az rest --method GET --uri $uri --headers "Authorization=Bearer $token" | ConvertFrom-Json

# Remove appCommandLine
$current.properties.appCommandLine = $null

# Update config
$body = $current | ConvertTo-Json -Depth 10
az rest --method PUT --uri $uri --headers "Authorization=Bearer $token" --body $body

Write-Host "✓ Startup command cleared" -ForegroundColor Green
Write-Host "Restarting app..." -ForegroundColor Yellow
az webapp restart --name $WebAppName --resource-group $ResourceGroup
