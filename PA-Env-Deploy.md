# PA Environment Deployment Guide

## Overview
This document outlines the deployment requirements and architecture for deploying the G-Cloud 15 automation tool to PA Consulting's Azure dev environment. This deployment will use SharePoint Online for document storage instead of Azure Blob Storage, integrate with PA's Microsoft 365 SSO, and maintain a serverless, cost-effective architecture with no public access.

## Architecture Requirements

### Core Services
1. **Azure Functions** (Backend API)
   - Serverless compute for API endpoints
   - Private endpoints only (no public access)
   - Python runtime
   - HTTP trigger for API routes

2. **Azure Static Web Apps** or **App Service** (Frontend)
   - React frontend application
   - Private endpoints only
   - Custom domain: `PA-G-Cloud15` or similar

3. **SharePoint Online** (Document Storage)
   - Primary storage for all documents (Word, PDF, metadata)
   - Integration via Microsoft Graph API
   - No Azure Blob Storage needed for documents

4. **Azure Storage Account** (Optional - Temp Data Only)
   - May still be needed for temporary file processing
   - Private endpoints only
   - Minimal storage tier (if needed at all)

5. **Azure Key Vault** (Secrets Management)
   - Store SharePoint credentials
   - Store application secrets
   - Store connection strings

6. **Azure App Registration** (Authentication)
   - Microsoft 365 SSO integration
   - OAuth 2.0 / OpenID Connect
   - Required permissions for SharePoint and Graph API

### Network Architecture
- **Private Endpoints**: All services accessible only via private network
- **VNet Integration**: Functions and App Service integrated with PA's VNet
- **Private DNS Zones**: For private endpoint resolution
- **No Public IPs**: All services have private access only

## Authentication & Authorization

### Microsoft 365 SSO Integration
- Use Microsoft Identity Platform (Azure AD)
- OAuth 2.0 authorization code flow
- Required scopes:
  - `User.Read` - Basic user profile
  - `Files.ReadWrite.All` or `Sites.ReadWrite.All` - SharePoint access
  - `offline_access` - Refresh tokens

### User Roles
- Standard users: Can create/edit their own proposals
- Admin users: Can view all proposals, analytics, lock questionnaires

## SharePoint Integration

### Document Storage Structure
```
PA SharePoint Site
└── G-Cloud 15/
    └── PA Services/
        └── Cloud Support Services LOT {2a|2b|3}/
            └── {Service Name}/
                ├── PA GC15 SERVICE DESC {Service Name}.docx
                ├── PA GC15 SERVICE DESC {Service Name}.pdf
                ├── PA GC15 Pricing Doc {Service Name}.docx
                ├── questionnaire_responses.json
                └── OWNER {Owner Email}.txt
```

### Required SharePoint Permissions
- Read/Write access to document libraries
- Ability to create folders and files
- Metadata management

### Implementation Approach
- Use Microsoft Graph API for SharePoint operations
- Replace Azure Blob Storage calls with Graph API calls
- Maintain existing service abstraction layer
- Add SharePoint Online implementation to `sharepoint_service`

## Deployment Script Requirements

### CLI Script Features
1. **Interactive Prompts** for:
   - Resource group name (or select existing)
   - Function App name (or select existing)
   - Static Web App / App Service name (or select existing)
   - Storage Account name (if needed, or select existing)
   - Key Vault name (or select existing)
   - App Registration name (or select existing)
   - SharePoint site URL
   - Custom domain name (e.g., PA-G-Cloud15)

2. **Resource Validation**:
   - Check if resources already exist
   - Validate naming conventions
   - Check required permissions

3. **Configuration**:
   - Set environment variables
   - Configure private endpoints
   - Set up VNet integration
   - Configure authentication

4. **Deployment Steps**:
   - Create/configure Azure resources
   - Deploy Function App code
   - Deploy Static Web App / App Service
   - Configure authentication
   - Set up SharePoint integration
   - Configure private endpoints
   - Test connectivity

## File Structure

### PA Deployment Folder Structure
```
pa-deployment/
├── README.md
├── deploy.sh (or deploy.ps1 for Windows)
├── config/
│   ├── function-app-settings.json
│   ├── static-web-app-config.json
│   └── environment-variables.env
├── scripts/
│   ├── setup-resources.sh
│   ├── deploy-functions.sh
│   ├── deploy-frontend.sh
│   └── configure-auth.sh
├── backend/
│   └── (minimal backend code - only what's needed)
├── frontend/
│   └── (minimal frontend code - only what's needed)
├── docs/
│   └── PA-DEPLOYMENT-GUIDE.md
└── .gitignore
```

## Code Modifications Required

### Backend Changes
1. **SharePoint Service Implementation**:
   - Add real SharePoint Online integration using Microsoft Graph API
   - Replace Azure Blob Storage calls with Graph API calls
   - Maintain existing service interface

2. **Authentication**:
   - Integrate with Microsoft Identity Platform
   - Replace current auth with Azure AD authentication
   - Handle token refresh

3. **Environment Configuration**:
   - Remove Azure Blob Storage connection strings
   - Add SharePoint site URL and credentials
   - Add Microsoft Graph API configuration

### Frontend Changes
1. **Authentication**:
   - Integrate Microsoft Authentication Library (MSAL)
   - Replace current auth with Azure AD login
   - Handle token acquisition and refresh

2. **API Configuration**:
   - Update API base URL to use private endpoint
   - Configure authentication headers

## Deployment Checklist

### Pre-Deployment
- [ ] PA Azure subscription access confirmed
- [ ] SharePoint site created and accessible
- [ ] App Registration created in Azure AD
- [ ] Required permissions granted
- [ ] VNet and private endpoints configured
- [ ] DNS zones configured

### Deployment
- [ ] Run deployment script
- [ ] Verify all resources created
- [ ] Deploy backend code
- [ ] Deploy frontend code
- [ ] Configure authentication
- [ ] Test SharePoint connectivity
- [ ] Test document upload/download
- [ ] Test user authentication

### Post-Deployment
- [ ] Verify private endpoints working
- [ ] Test from PA network
- [ ] Verify no public access
- [ ] Performance testing
- [ ] Security review

## Cost Optimization

### Serverless Approach
- Azure Functions: Consumption plan (pay per execution)
- Static Web Apps: Free tier if possible, or minimal App Service plan
- Storage: Minimal if needed (only for temp files)
- Private Endpoints: Standard pricing

### Monitoring
- Azure Application Insights
- Function App metrics
- Cost alerts

## Security Considerations

1. **No Public Access**: All services behind private endpoints
2. **Network Isolation**: VNet integration required
3. **Secrets Management**: All secrets in Key Vault
4. **Authentication**: Microsoft 365 SSO only
5. **Data Encryption**: At rest and in transit
6. **Access Control**: Role-based access control (RBAC)

## Support & Maintenance

### Documentation
- Deployment guide for PA team
- Troubleshooting guide
- Architecture diagrams

### Monitoring
- Application Insights dashboards
- Alert rules for errors
- Cost monitoring

## Next Steps

1. Create PA deployment folder structure
2. Extract and modify code for SharePoint integration
3. Create deployment scripts with interactive prompts
4. Test deployment in PA dev environment
5. Document deployment process
6. Hand over to PA team

