# SIMPLE FIX: Just rebuild - the new Dockerfile should work
# The startup command issue might resolve itself with the new image

Write-Host "=== SIMPLE SOLUTION ===" -ForegroundColor Green
Write-Host ""
Write-Host "The new Dockerfile (pushed to git) has NO CMD override." -ForegroundColor Yellow
Write-Host "This means it will use nginx:alpine's default, which works." -ForegroundColor Yellow
Write-Host ""
Write-Host "Steps:" -ForegroundColor Cyan
Write-Host "1. git pull origin main" -ForegroundColor White
Write-Host "2. .\scripts\build-and-push-images.ps1  (select option 1)" -ForegroundColor White  
Write-Host "3. .\scripts\deploy-frontend.ps1" -ForegroundColor White
Write-Host ""
Write-Host "The new image will work because:" -ForegroundColor Green
Write-Host "- No CMD override = uses nginx:alpine default" -ForegroundColor White
Write-Host "- nginx:alpine default = 'nginx -g daemon off;' (correct syntax)" -ForegroundColor White
Write-Host ""
Write-Host "If it still fails, the startup command override is the issue." -ForegroundColor Yellow
Write-Host "But try rebuild first - it should work!" -ForegroundColor Green
