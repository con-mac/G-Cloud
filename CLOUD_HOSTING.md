# Cloud Hosting Guide

## Overview
This document outlines the cloud hosting strategy for the G-Cloud Proposal Automation System, including current AWS deployment and future Azure migration plans.

---

## Current Hosting (AWS)

### Infrastructure
- **Frontend**: S3 + CloudFront (Static website hosting)
- **Backend**: Lambda Functions (API Gateway)
- **Storage**: S3 (Documents, static assets)
- **Infrastructure as Code**: Terraform

### Deployment

#### Frontend Deployment
```bash
# Deploy to S3/CloudFront
cd /home/con-mac/dev/projects/gcloud_automate
bash scripts/deploy-frontend.sh dev
```

**Frontend URL**: https://d26fp71s00gmkk.cloudfront.net

#### Backend Deployment
```bash
# Deploy Lambda functions
cd /home/con-mac/dev/projects/gcloud_automate
bash scripts/deploy-pdf-converter.sh dev
```

**API Gateway URL**: Retrieved from Terraform outputs

### Environment Variables
- **VITE_API_BASE_URL**: Set during frontend build (from Terraform outputs)
- **AWS_REGION**: eu-west-2
- **PROJECT_NAME**: gcloud-automation

---

## Future Hosting (Azure)

### Planned Migration
Once Azure account is provisioned, the system will be migrated to Azure for better compliance with company policy.

### Azure Services (Planned)
- **Frontend**: Azure Static Web Apps or Azure Blob Storage + CDN
- **Backend**: Azure Functions or Azure App Service
- **Storage**: Azure Blob Storage
- **SharePoint**: Native Microsoft Graph API integration
- **Authentication**: Azure AD (Microsoft 365 SSO)

### Benefits of Azure Migration
1. **Native SharePoint Integration**: Direct access to SharePoint via Microsoft Graph API
2. **SSO Integration**: Seamless Microsoft 365 authentication
3. **Company Policy Compliance**: Better alignment with PA Consulting infrastructure
4. **Cost Optimization**: Potential cost savings with Azure credits
5. **Security**: Enhanced security features and compliance certifications

---

## Deployment Scripts

### Current Scripts (AWS)
- `scripts/deploy-frontend.sh` - Deploy frontend to S3/CloudFront
- `scripts/deploy-pdf-converter.sh` - Deploy PDF converter Lambda
- `infrastructure/terraform/` - Terraform infrastructure code

### Future Scripts (Azure)
- Azure deployment scripts will be created during migration
- Azure CLI or ARM/Bicep templates for infrastructure
- Azure DevOps pipelines for CI/CD

---

## Local Development

### Requirements
- Node.js 18+ (for frontend)
- Python 3.10+ (for backend)
- AWS CLI configured (for deployment)
- Terraform (for infrastructure)

### Starting Development Servers

#### Backend
```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

#### Frontend
```bash
cd frontend
npm run dev
```

**Note**: Both servers must be running for the application to work.

---

## Environment Configuration

### Local Development
- Frontend: `http://localhost:3000`
- Backend: `http://localhost:8000`
- API: `http://localhost:8000/api/v1`

### AWS Deployment
- Frontend: CloudFront URL (from Terraform outputs)
- Backend: API Gateway URL (from Terraform outputs)
- API: `https://[api-gateway-url]/api/v1`

### Azure Deployment (Future)
- Frontend: Azure Static Web App URL
- Backend: Azure Function App URL
- API: `https://[function-app-url]/api/v1`

---

## Configuration Files

### Frontend
- `frontend/.env.local` - Local environment variables
- `frontend/vite.config.ts` - Vite configuration
- `frontend/package.json` - Dependencies and scripts

### Backend
- `backend/.env` - Local environment variables
- `backend/requirements.txt` - Python dependencies
- `backend/Dockerfile` - Lambda container configuration

### Infrastructure
- `infrastructure/terraform/` - Terraform configuration
- `infrastructure/terraform/main.tf` - Main infrastructure
- `infrastructure/terraform/variables.tf` - Variables
- `infrastructure/terraform/outputs.tf` - Outputs

---

## Migration Checklist

### Pre-Migration
- [ ] Provision Azure account
- [ ] Set up Azure subscription
- [ ] Configure Azure AD app registration
- [ ] Set up Azure DevOps (if using)
- [ ] Review Azure pricing and quotas

### Migration Steps
- [ ] Create Azure resource group
- [ ] Deploy frontend to Azure Static Web Apps or Blob Storage
- [ ] Deploy backend to Azure Functions or App Service
- [ ] Configure Azure Blob Storage for document storage
- [ ] Set up Azure AD authentication
- [ ] Configure Microsoft Graph API access
- [ ] Update frontend API endpoints
- [ ] Test end-to-end workflow
- [ ] Update DNS/domain configuration
- [ ] Set up monitoring and logging

### Post-Migration
- [ ] Verify all functionality works
- [ ] Performance testing
- [ ] Security audit
- [ ] Documentation updates
- [ ] Team training
- [ ] Decommission AWS resources (if applicable)

---

## Notes

### Current Status
- ✅ Frontend deployed to AWS S3/CloudFront
- ✅ Backend deployed to AWS Lambda
- ✅ PDF converter Lambda working
- ✅ Document generation working
- ✅ SharePoint integration (mock) implemented
- ⏳ Azure migration pending account provisioning

### Future Considerations
- Azure AD SSO integration
- Native SharePoint integration via Microsoft Graph API
- Azure Key Vault for secrets management
- Azure Monitor for logging and monitoring
- Azure DevOps for CI/CD pipelines

---

## Links

### Current Deployment
- **Frontend**: https://d26fp71s00gmkk.cloudfront.net
- **API Gateway**: Retrieved from Terraform outputs
- **Terraform**: `infrastructure/terraform/`

### Documentation
- **Production Roadmap**: `production_roadmap.md`
- **Implementation Plan**: `IMPLEMENTATION_PLAN.md`
- **SharePoint Integration Guide**: `SHAREPOINT_INTEGRATION_GUIDE.md`
- **This Document**: `CLOUD_HOSTING.md`

