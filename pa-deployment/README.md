# PA Deployment

Deployment scripts and guides for PA Consulting Azure environment.

## Application Access

**Sign In URL:** [https://pa-gcloud15-web.azurewebsites.net](https://pa-gcloud15-web.azurewebsites.net)

For all access URLs and troubleshooting, see [ACCESS-URLS.md](./ACCESS-URLS.md)

## Quick Start

1. **Initial Deployment:**
   ```powershell
   .\deploy.ps1
   ```

2. **After SSO Configuration, Rebuild Frontend:**
   ```powershell
   .\scripts\build-and-push-images.ps1
   .\scripts\deploy-frontend.ps1
   ```

## Documentation

See [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) for complete deployment instructions, troubleshooting, and architecture overview.

## Architecture

- **Frontend:** React app served via Nginx in Docker container (Azure Web App)
- **Backend:** FastAPI application (Azure Function App)
- **Authentication:** Microsoft 365 SSO via Azure AD App Registration
- **Storage:** SharePoint for document storage
- **Secrets:** Azure Key Vault
- **Container Registry:** Azure Container Registry (ACR) for Docker images
- **Security:** Azure AD Security Groups for role-based access (Admin vs Employee)
