# How to Switch Azure Accounts in VS Code PowerShell

## Quick Steps

### 1. Check Current Account
```powershell
az account show
```
This shows which account/subscription you're currently using.

### 2. List All Accounts
```powershell
az account list --output table
```
This shows all accounts you're logged into (if any).

### 3. Log Out (If Needed)
If you're logged into a different account:
```powershell
az logout
```

### 4. Log Into New Account
```powershell
az login
```
This will:
- Open your default browser
- Ask you to sign in with your Microsoft account
- Sign in with your **M365 Business Basic account** email
- Show you all available subscriptions

### 5. Select the Correct Subscription
After logging in, you'll see a list of subscriptions. Select the one for your new Azure account:

```powershell
# List all subscriptions
az account list --output table

# Set the correct subscription (use Subscription ID or Name)
az account set --subscription "<subscription-id-or-name>"
```

### 6. Verify You're on the Right Account
```powershell
az account show
```
Check:
- **Name**: Should match your M365 Business Basic subscription
- **TenantId**: Should match your M365 tenant
- **User**: Should be your M365 Business Basic account email

## Example Workflow

```powershell
# 1. Check current account
az account show

# 2. Log out if needed
az logout

# 3. Log in to new account
az login

# 4. After browser login, list subscriptions
az account list --output table

# 5. Set the correct subscription
az account set --subscription "Your Subscription Name"
# OR
az account set --subscription "12345678-1234-1234-1234-123456789012"

# 6. Verify
az account show
```

## If You Have Multiple Accounts

If you need to manage multiple Azure accounts:

```powershell
# List all accounts you're logged into
az account list --output table

# Switch between accounts
az account set --subscription "<subscription-id>"

# Log out of all accounts
az logout
```

## Troubleshooting

### "No subscriptions found"
- Make sure you signed in with the correct Microsoft account
- Verify the account has an active Azure subscription
- Check if you need to accept terms in Azure Portal first

### "Access denied"
- The account might not have permissions
- Try logging in with an account that has Owner or Contributor role

### "Multiple subscriptions, which one?"
- Use `az account list --output table` to see all
- Look for the subscription name that matches your M365 Business Basic account
- Use the Subscription ID (GUID) to set it explicitly

## Quick Verification Commands

```powershell
# See current account details
az account show --output table

# See all subscriptions
az account list --output table

# See current user
az account show --query user.name -o tsv

# See tenant ID
az account show --query tenantId -o tsv
```

