# App Service Capacity Issues - Guide

## Understanding the Error

**Error:** "No available instances to satisfy this request. App Service is attempting to increase capacity."

**What this means:**
- This is about **App Service Plan** capacity, NOT App Service Environment (ASE)
- The region you selected is temporarily at capacity for the SKU you're requesting
- Azure is trying to scale up capacity automatically, but it takes time

## App Service Environment (ASE) vs App Service Plan

### App Service Plan (What You're Using)
- **What it is:** Shared or dedicated infrastructure for hosting apps
- **Cost:** Pay-as-you-go, relatively inexpensive
- **SKU used:** B1 (Basic tier) - $13-55/month
- **Capacity issue:** Region temporarily at capacity for this SKU
- **Solution:** Try different region, wait, or use different SKU

### App Service Environment (ASE) - NOT NEEDED
- **What it is:** Premium isolated infrastructure (dedicated VNet, private networking)
- **Cost:** $1,000-3,000+/month (very expensive)
- **When needed:** High security/compliance requirements, private networking only
- **For your use case:** **NOT NECESSARY** - overkill and expensive
- **Creation time:** 30-60 minutes

## Solutions (In Order of Preference)

### Solution 1: Try a Different Region (Easiest)
The script uses `uksouth` by default. Try these regions instead:

```powershell
# When prompted for location, try:
- eastus (US East)
- westeurope (West Europe)
- northeurope (North Europe)
- centralus (US Central)
```

**Why this works:** Different regions have different capacity availability.

### Solution 2: Use a Different SKU (If Region Change Doesn't Work)
The script uses **B1 (Basic)** SKU. You can manually create a plan with a different SKU:

```powershell
# Create App Service Plan with F1 (Free) SKU first (if available)
az appservice plan create `
    --name "pa-gcloud15-web-plan" `
    --resource-group "pa-gcloud15-rg" `
    --location "eastus" `
    --sku F1 `
    --is-linux

# Then run deploy.ps1 - it will find and use the existing plan
```

**SKU Options:**
- **F1 (Free)** - Limited, but good for testing
- **B1 (Basic)** - $13/month - what script uses
- **S1 (Standard)** - $70/month - more capacity
- **P1V2 (Premium)** - $146/month - even more capacity

### Solution 3: Wait and Retry
Azure is automatically scaling capacity. Wait 10-15 minutes and try again.

### Solution 4: Create App Service Plan Manually First
If you want to ensure the plan exists before deployment:

```powershell
# 1. Create the plan manually
az appservice plan create `
    --name "pa-gcloud15-web-plan" `
    --resource-group "pa-gcloud15-rg" `
    --location "eastus" `
    --sku B1 `
    --is-linux

# 2. Verify it was created
az appservice plan show --name "pa-gcloud15-web-plan" --resource-group "pa-gcloud15-rg"

# 3. Then run deploy.ps1 - it will find and use the existing plan
```

**Note:** The script will automatically detect and use an existing plan if it exists.

## Should You Create App Service Environment (ASE)?

**Short answer: NO**

**Reasons:**
1. **Expensive:** $1,000-3,000+/month vs $13/month for Basic plan
2. **Overkill:** You don't need isolated infrastructure for this use case
3. **Time-consuming:** Takes 30-60 minutes to create
4. **Not the issue:** The capacity problem is with regular App Service Plans, not ASE

**When you WOULD need ASE:**
- Regulatory compliance requiring isolated infrastructure
- Private networking only (no public internet)
- Very high security requirements
- Large enterprise deployments

## Should You Create App Registration Manually?

**Short answer: OPTIONAL, but script handles it**

**The script automatically:**
- Creates App Registration if it doesn't exist
- Finds and uses existing App Registration if it exists
- Configures SPA platform correctly
- Sets up all required permissions

**When you MIGHT want to create it manually:**
1. **If you have permission issues** - Creating it manually ensures you have ownership
2. **If you want to pre-configure it** - Set up redirect URIs, permissions before deployment
3. **If script fails** - Manual creation as fallback

**How to create manually:**
1. Azure Portal → Azure AD → App registrations → New registration
2. Name: `pa-gcloud15-app` (or your chosen name)
3. Supported account types: Single tenant
4. Redirect URI: Leave blank (script will add it)
5. Register
6. Then run `deploy.ps1` - it will find and use it

## Recommended Approach

### For Your Fresh Deployment:

1. **Try a different region first:**
   - When prompted for location, use `eastus` or `westeurope` instead of `uksouth`

2. **If that fails, create App Service Plan manually:**
   ```powershell
   # Create plan in a different region
   az appservice plan create `
       --name "pa-gcloud15-web-plan" `
       --resource-group "pa-gcloud15-rg" `
       --location "eastus" `
       --sku B1 `
       --is-linux
   ```

3. **Then run deploy.ps1:**
   - It will detect the existing plan and use it
   - App Registration will be created automatically

### Quick Fix Script

I can create a script that:
- Tries multiple regions automatically
- Creates App Service Plan if needed
- Handles capacity issues gracefully

Would you like me to create this?

## Summary

| Resource | Manual Creation Needed? | Why |
|----------|----------------------|-----|
| **App Service Environment** | ❌ NO | Too expensive, not the issue |
| **App Service Plan** | ⚠️ Maybe | Only if region capacity issue persists |
| **App Registration** | ⚠️ Optional | Script handles it, but manual is fine |
| **Function App** | ❌ NO | Uses Consumption plan (no plan needed) |
| **Web App** | ❌ NO | Script creates it after plan exists |

**Best approach:** Try different region first, then create plan manually if needed.

