# G-Cloud Proposal Automation System

A comprehensive web application designed to automate and streamline the creation, validation, and management of G-Cloud framework proposals and renewals.

## 🎯 Overview

This system helps organisations efficiently manage G-Cloud proposals by:
- ✅ Automating word count and data validation
- 📊 Tracking proposal completion status
- 🔔 Sending deadline alerts
- 📝 Managing changes with full audit trail
- 📚 Reviewing and comparing previous proposals
- ☁️ Integrating with Azure and SharePoint

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Cloud                          │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  App Service │  │   Azure SQL  │  │ Blob Storage │ │
│  │   (Frontend) │  │   Database   │  │  (Documents) │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  App Service │  │ Redis Cache  │  │  Functions   │ │
│  │   (Backend)  │  │              │  │(Notifications)│ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │  Azure AD    │  │  Key Vault   │                    │
│  │    (Auth)    │  │  (Secrets)   │                    │
│  └──────────────┘  └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
                           │
                    Microsoft Graph API
                           │
                   ┌───────▼────────┐
                   │   SharePoint   │
                   │   (Documents)  │
                   └────────────────┘
```

## 📁 Project Structure

```
gcloud_automate/
├── backend/                 # FastAPI backend application
│   ├── app/
│   │   ├── api/            # API endpoints
│   │   ├── core/           # Core functionality (config, security)
│   │   ├── models/         # Database models
│   │   ├── schemas/        # Pydantic schemas
│   │   ├── services/       # Business logic
│   │   └── utils/          # Utility functions
│   ├── tests/              # Backend tests
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Backend container
│
├── frontend/               # React TypeScript frontend
│   ├── src/
│   │   ├── components/     # Reusable React components
│   │   ├── pages/          # Page components
│   │   ├── hooks/          # Custom React hooks
│   │   ├── services/       # API services
│   │   ├── store/          # State management
│   │   ├── types/          # TypeScript types
│   │   └── utils/          # Utility functions
│   ├── public/             # Static assets
│   ├── tests/              # Frontend tests
│   ├── package.json        # Node dependencies
│   └── Dockerfile          # Frontend container
│
├── shared/                 # Shared code between frontend/backend
│   ├── types/              # Shared TypeScript/Python types
│   └── constants/          # Shared constants
│
├── infrastructure/         # Infrastructure as Code
│   ├── terraform/          # Terraform configurations
│   ├── bicep/              # Azure Bicep templates
│   └── scripts/            # Deployment scripts
│
├── docs/                   # Documentation
│   ├── requirements.md     # Requirements document (living document)
│   ├── architecture.md     # Architecture details
│   ├── api.md              # API documentation
│   └── user-guide.md       # User documentation
│
├── .github/                # GitHub Actions workflows
│   └── workflows/          # CI/CD pipelines
│
└── README.md               # This file
```

## 🚀 Getting Started

### Prerequisites

- **Node.js** 18+ and npm/yarn
- **Python** 3.11+
- **Docker** and Docker Compose
- **Azure Account** with appropriate permissions
- **Azure CLI** installed and configured

### Local Development Setup

#### 1. Clone the repository

```bash
git clone <repository-url>
cd gcloud_automate
```

#### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Run database migrations
alembic upgrade head

# Start the backend server
uvicorn app.main:app --reload
```

Backend will be available at `http://localhost:8000`  
API docs at `http://localhost:8000/docs`

#### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Start the development server
npm run dev
```

Frontend will be available at `http://localhost:5173`

### Docker Setup (Recommended)

```bash
# Build and start all services
docker-compose up --build

# Backend: http://localhost:8000
# Frontend: http://localhost:3000
```

## 🧪 Testing

### Backend Tests

```bash
cd backend
pytest
pytest --cov=app tests/  # With coverage
```

### Frontend Tests

```bash
cd frontend
npm test
npm run test:coverage
```

### End-to-End Tests

```bash
npm run test:e2e
```

## 📦 Deployment

### Azure Deployment

Deployment is automated via GitHub Actions. See `.github/workflows/deploy.yml`

Manual deployment:

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply

# Or using Azure Bicep
az deployment group create \
  --resource-group gcloud-automation-rg \
  --template-file infrastructure/bicep/main.bicep
```

## 🔧 Configuration

### Environment Variables

#### Backend (.env)
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/gcloud_db
AZURE_AD_TENANT_ID=your-tenant-id
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_STORAGE_CONNECTION_STRING=your-connection-string
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key
```

#### Frontend (.env)
```bash
VITE_API_URL=http://localhost:8000
VITE_AZURE_AD_CLIENT_ID=your-client-id
VITE_AZURE_AD_TENANT_ID=your-tenant-id
```

## 📖 Key Features

### Phase 1: MVP (Current)
- ✅ Proposal creation and editing
- ✅ Real-time word count validation
- ✅ Data type validation
- ✅ Section-based structure
- ✅ User authentication (Azure AD)
- ✅ Deadline tracking
- ✅ Completion status

### Phase 2: Integration (In Progress)
- 🚧 SharePoint connectivity
- 🚧 Document import/export
- 🚧 Document parsing

### Phase 3: Change Management (Planned)
- 📋 Version control
- 📋 Change tracking
- 📋 Audit trail
- 📋 Section locking

### Phase 4: Notifications (Planned)
- 📋 Deadline alerts
- 📋 Email notifications
- 📋 In-app notifications

### Phase 5: Advanced Features (Planned)
- 📋 Proposal comparison
- 📋 Analytics dashboard
- 📋 Advanced reporting

## 🤝 Contributing

This is an internal project. Please follow these guidelines:

1. Create a feature branch from `main`
2. Make your changes with clear, descriptive commits
3. Write/update tests for your changes
4. Ensure all tests pass
5. Create a pull request with a clear description
6. Request review from team members

### Commit Message Convention

```
feat: Add new validation rule for pricing section
fix: Correct word count calculation for bulleted lists
docs: Update API documentation for auth endpoints
test: Add tests for proposal creation workflow
chore: Update dependencies
```

## 📝 Documentation

- [Requirements Document](docs/requirements.md) - Comprehensive requirements and specifications
- [Architecture Guide](docs/architecture.md) - Technical architecture details
- [API Documentation](http://localhost:8000/docs) - Interactive API docs (when running)
- [User Guide](docs/user-guide.md) - End-user documentation

## 🐛 Known Issues

See [GitHub Issues](https://github.com/your-org/gcloud_automate/issues) for current bugs and feature requests.

## 📊 Monitoring and Logging

- **Application Insights**: Azure Application Insights for telemetry
- **Logs**: Structured logging with correlation IDs
- **Alerts**: Configured for errors, performance issues, and downtime

Access monitoring dashboard: [Azure Portal](https://portal.azure.com)

## 🔐 Security

- All data encrypted at rest and in transit
- Azure AD for authentication
- Role-based access control (RBAC)
- Secrets stored in Azure Key Vault
- Regular security scanning and penetration testing

Report security issues to: security@your-organisation.com

## 📜 License

Proprietary - Internal Use Only

## 👥 Team

- **Product Owner**: TBD
- **Tech Lead**: TBD
- **Backend Developers**: TBD
- **Frontend Developers**: TBD
- **DevOps Engineer**: TBD

## 📞 Support

- **Internal Support**: support@your-organisation.com
- **Documentation**: [Confluence/Wiki Link]
- **Slack Channel**: #gcloud-automation

## 🗺️ Roadmap

### Q4 2025
- ✅ Phase 1: MVP delivery
- 🚧 Phase 2: SharePoint integration

### Q1 2026
- 📋 Phase 3: Change management
- 📋 Phase 4: Notification system

### Q2 2026
- 📋 Phase 5: Advanced features
- 📋 Production deployment

### Future
- AI-powered content suggestions
- Mobile applications
- Advanced analytics

---

**Last Updated**: October 28, 2025  
**Version**: 1.0.0

