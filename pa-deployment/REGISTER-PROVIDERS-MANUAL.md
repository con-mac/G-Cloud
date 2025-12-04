# Manual Resource Provider Registration

## Quick Steps (Azure Portal)

1. **Go to Azure Portal:** https://portal.azure.com
2. **Navigate to:** Subscriptions → **Your Subscription Name** → Resource providers
3. **Search and register each provider** (click "Register" button):
   - `Microsoft.KeyVault`
   - `Microsoft.Web`
   - `Microsoft.Storage`
   - `Microsoft.ContainerRegistry`
   - `Microsoft.Insights`
   - `Microsoft.Network`
4. **Wait 1-2 minutes** for status to change to "Registered"
5. **Verify:** All should show status = "Registered" (green checkmark)

## Quick Steps (Azure CLI)

Run these commands in PowerShell:

```powershell
# Register all providers
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.Network

# Check registration status (wait 1-2 minutes, then check)
az provider show --namespace Microsoft.KeyVault --query "registrationState" -o tsv
az provider show --namespace Microsoft.Web --query "registrationState" -o tsv
az provider show --namespace Microsoft.Storage --query "registrationState" -o tsv
az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" -o tsv
az provider show --namespace Microsoft.Insights --query "registrationState" -o tsv
az provider show --namespace Microsoft.Network --query "registrationState" -o tsv

# All should return: "Registered"
```

## Why This Is Needed

New Azure subscriptions don't have all resource providers registered by default. Without registration, you'll get errors like:
- "The subscription is not registered to use namespace 'Microsoft.KeyVault'"
- "Resource provider not registered"

## After Registration

Once all providers show "Registered", you can proceed with `deploy.ps1`.

