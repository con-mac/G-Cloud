# Developer Guides

This directory contains all developer documentation organized by category.

## 📁 Folder Structure

### AWS_Deploys/
Deployment guides and status documents for AWS cloud hosting.

- **AWS_DEPLOYMENT_GUIDE.md** - Comprehensive AWS deployment guide
- **DEPLOYMENT_STATUS.md** - Current deployment status with URLs and verification steps
- **../infrastructure/terraform/aws/DEPLOY.md** - Quick deploy commands for AWS infrastructure

### Local_Deploys/
Local development setup and integration guides.

- **SHAREPOINT_INTEGRATION_GUIDE.md** - SharePoint integration guide with local URLs
- **TEMPLATE_CREATION_GUIDE.md** - Template-based proposal creation guide

### Project_Strategies/
High-level project planning, architecture, and strategy documents.

- **CLOUD_HOSTING.md** - Cloud hosting strategy and approach

### Requirements/
Project requirements and specifications.

- (To be populated)

### Graveyard/
Deprecated or archived documentation.

- (To be populated)

## 🔗 Quick Reference: AWS URLs

**Frontend URL (CloudFront):**
- Location: `AWS_Deploys/DEPLOYMENT_STATUS.md`
- Format: `https://d26fp71s00gmkk.cloudfront.net`

**API Gateway URL:**
- Location: `AWS_Deploys/DEPLOYMENT_STATUS.md`
- Format: `https://jqms1xopz9.execute-api.eu-west-2.amazonaws.com`

**Local Development URLs:**
- Location: `Local_Deploys/SHAREPOINT_INTEGRATION_GUIDE.md`
- Frontend: `http://localhost:5173`
- Backend: `http://localhost:8000`

## 📝 Notes

- All deployment-related URLs are documented in `AWS_Deploys/DEPLOYMENT_STATUS.md`
- Local development URLs are in `Local_Deploys/SHAREPOINT_INTEGRATION_GUIDE.md`
- Infrastructure deployment commands are in `infrastructure/terraform/aws/DEPLOY.md`

