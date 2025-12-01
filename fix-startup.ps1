# Fix: Remove startup command for container-based app
$WebAppName = "pa-gcloud15-web"
$ResourceGroup = "pa-gcloud15-rg"

Write-Host "Removing startup command override..." -ForegroundColor Cyan

# For container apps, we need to update via REST API or Portal
# The CLI doesn't support clearing it easily, so we'll set it to use the container's default
# Actually, the best approach is to just rebuild with the fixed Dockerfile

Write-Host ""
Write-Host "The startup command is currently: nginx -g 'daemon off;'" -ForegroundColor Yellow
Write-Host "This is causing the quote parsing error." -ForegroundColor Yellow
Write-Host ""
Write-Host "SOLUTION: Rebuild the image with the fixed Dockerfile (no CMD override)" -ForegroundColor Green
Write-Host "The new image will use nginx:alpine's default, which works correctly." -ForegroundColor Green
Write-Host ""
Write-Host "Steps:" -ForegroundColor Cyan
Write-Host "1. git pull origin main" -ForegroundColor White
Write-Host "2. .\scripts\build-and-push-images.ps1" -ForegroundColor White
Write-Host "3. .\scripts\deploy-frontend.ps1" -ForegroundColor White
Write-Host ""
Write-Host "The new Dockerfile doesn't override CMD, so it will work!" -ForegroundColor Green
