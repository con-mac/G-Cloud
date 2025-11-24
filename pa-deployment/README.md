# PA Environment Deployment

This folder contains the deployment scripts and code for deploying the G-Cloud 15 automation tool to PA Consulting's Azure dev environment.

## Overview

This deployment uses:
- **SharePoint Online** for document storage (via Microsoft Graph API)
- **Microsoft 365 SSO** for authentication
- **Private endpoints** only (no public access)
- **Serverless architecture** for cost efficiency

## Quick Start

1. Ensure you have Azure CLI installed and logged in
2. Ensure you have access to PA's Azure subscription
3. Run the deployment script:
   ```bash
   ./deploy.sh
   ```
   Or on Windows:
   ```powershell
   .\deploy.ps1
   ```

## Prerequisites

- Azure CLI 2.0+
- Access to PA Azure subscription
- Access to SharePoint site
- App Registration created in Azure AD
- VNet and private endpoints configured

## Documentation

- [Deployment Guide](docs/PA-DEPLOYMENT-GUIDE.md)
- [Architecture Overview](PA-Env-Deploy.md)

## Repository

This folder is designed to be pushed to a separate repository for PA-specific deployments.

