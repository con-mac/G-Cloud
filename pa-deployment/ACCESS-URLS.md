# G-Cloud 15 Application Access URLs

## Production Environment

### Frontend Application (Sign In)
**URL:** https://pa-gcloud15-web.azurewebsites.net

This is the main application URL where users can sign in using Microsoft 365 SSO.

### Backend API
**URL:** https://pa-gcloud15-api.azurewebsites.net

### API Documentation (if enabled)
**URL:** https://pa-gcloud15-api.azurewebsites.net/docs

---

## Quick Access

**Sign In:** [https://pa-gcloud15-web.azurewebsites.net](https://pa-gcloud15-web.azurewebsites.net)

---

## Notes

- Authentication: Microsoft 365 SSO (Azure AD)
- Access: Requires PA Consulting Azure AD account
- Admin Access: Requires membership in the configured admin security group

---

## Troubleshooting

If you cannot access the application:

1. **Check SSO Configuration:**
   - Run: `.\scripts\diagnose-msal-issues.ps1`

2. **Check CORS (if API calls fail):**
   - Run: `.\scripts\fix-cors.ps1`

3. **Verify Deployment:**
   - Check Azure Portal for resource status
   - Review deployment logs if needed

---

*Last Updated: $(Get-Date -Format "yyyy-MM-dd")*

