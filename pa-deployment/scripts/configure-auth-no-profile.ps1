# Wrapper script to run configure-auth.ps1 without PowerShell profile
# This bypasses any profile error handlers that might intercept JSON parse errors
# Usage: .\scripts\configure-auth-no-profile.ps1

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$authScript = Join-Path $scriptDir "configure-auth.ps1"

# Run the script without loading the profile
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $authScript

