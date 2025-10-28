# Getting Started with G-Cloud Automation System

Welcome! This guide will help you get started with the G-Cloud Proposal Automation System.

## 📋 What We've Built

You now have a complete application framework including:

### ✅ Backend (FastAPI + Python)
- **Complete project structure** with separation of concerns
- **6 database models** (User, Proposal, Section, ValidationRule, ChangeHistory, Notification)
- **Pydantic schemas** for API validation
- **Configuration management** with environment variables
- **Database migrations** with Alembic
- **Docker containerisation** ready for deployment

### ✅ Frontend (React + TypeScript)
- **Modern React 18** setup with Vite
- **TypeScript** for type safety
- **Material-UI** component library
- **Azure AD authentication** integration
- **API service layer** with error handling
- **State management** structure
- **Responsive design** foundation

### ✅ Infrastructure (Azure + Terraform)
- **Complete Terraform configuration** for Azure deployment
- **Docker Compose** for local development
- **PostgreSQL** database setup
- **Redis** caching layer
- **Azure services** configuration (App Services, Key Vault, Storage, etc.)

### ✅ Documentation
- **Comprehensive requirements document** (96 pages!)
- **Detailed architecture documentation**
- **Project README** with setup instructions
- **Infrastructure deployment guides**

---

## 🚀 Quick Start - Local Development

### Prerequisites

Ensure you have the following installed:
- **Docker** and **Docker Compose** (easiest option)
- OR: **Python 3.11+**, **Node.js 20+**, **PostgreSQL 16**, **Redis**

### Option 1: Using Docker (Recommended)

```bash
# 1. Navigate to the project directory
cd /home/con-mac/dev/projects/gcloud_automate

# 2. Start all services
docker-compose up --build

# Wait for services to start...

# 3. Access the application
# - Frontend: http://localhost:3000
# - Backend API: http://localhost:8000
# - API Documentation: http://localhost:8000/docs
```

### Option 2: Manual Setup

#### Backend Setup

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your settings

# Run database migrations
alembic upgrade head

# Start the backend server
uvicorn app.main:app --reload
```

Backend will be available at `http://localhost:8000`

#### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your settings

# Start the development server
npm run dev
```

Frontend will be available at `http://localhost:5173`

---

## 📁 Project Structure Overview

```
gcloud_automate/
├── backend/              # FastAPI backend
│   ├── app/
│   │   ├── api/         # API endpoints (to be built)
│   │   ├── core/        # Core configuration ✅
│   │   ├── models/      # Database models ✅
│   │   ├── schemas/     # API schemas ✅
│   │   ├── services/    # Business logic (to be built)
│   │   └── utils/       # Utilities (to be built)
│   ├── alembic/         # Database migrations ✅
│   ├── requirements.txt # Dependencies ✅
│   └── Dockerfile       # Container config ✅
│
├── frontend/            # React frontend
│   ├── src/
│   │   ├── components/  # UI components (to be built)
│   │   ├── pages/       # Pages (to be built)
│   │   ├── services/    # API client ✅
│   │   ├── types/       # TypeScript types ✅
│   │   └── styles/      # Styling ✅
│   ├── package.json     # Dependencies ✅
│   └── Dockerfile       # Container config ✅
│
├── infrastructure/      # IaC and deployment
│   └── terraform/       # Azure Terraform ✅
│
├── docs/                # Documentation
│   ├── requirements.md  # Requirements ✅
│   └── architecture.md  # Architecture ✅
│
├── docker-compose.yml   # Local dev setup ✅
├── README.md           # Project overview ✅
└── .gitignore          # Git ignore rules ✅
```

---

## 🎯 Next Steps - Phase 1 MVP

To complete the MVP (Phase 1), we need to build:

### 1. Backend API Endpoints
```bash
backend/app/api/routes/
├── auth.py          # Login, logout, get current user
├── proposals.py     # CRUD operations for proposals
├── sections.py      # CRUD operations for sections
└── validation.py    # Validation endpoints
```

### 2. Backend Services
```bash
backend/app/services/
├── proposal_service.py      # Proposal business logic
├── section_service.py       # Section business logic
├── validation_service.py    # Validation engine
└── word_counter.py         # Word counting utility
```

### 3. Frontend Pages
```bash
frontend/src/pages/
├── Dashboard/          # Main dashboard
├── ProposalList/       # List all proposals
├── ProposalEditor/     # Edit proposal and sections
└── Login/             # Login page
```

### 4. Frontend Components
```bash
frontend/src/components/
├── ProposalCard/       # Proposal card component
├── SectionEditor/      # Section editing with validation
├── ValidationIndicator/ # Show validation status
└── Navigation/         # App navigation
```

### 5. Database Setup
```bash
# Create initial migration
cd backend
alembic revision --autogenerate -m "Initial schema"
alembic upgrade head
```

---

## 🔧 Configuration Checklist

Before deploying or running locally, ensure you configure:

### Backend (.env)
- [ ] `DATABASE_URL` - PostgreSQL connection string
- [ ] `REDIS_URL` - Redis connection string
- [ ] `SECRET_KEY` - Random secret key (use: `openssl rand -hex 32`)
- [ ] `AZURE_AD_*` - Azure AD credentials
- [ ] `AZURE_STORAGE_CONNECTION_STRING` - For document storage

### Frontend (.env)
- [ ] `VITE_API_URL` - Backend API URL
- [ ] `VITE_AZURE_AD_CLIENT_ID` - Azure AD client ID
- [ ] `VITE_AZURE_AD_TENANT_ID` - Azure AD tenant ID

---

## 📚 Key Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| **Requirements** | Full system requirements and specifications | `docs/requirements.md` |
| **Architecture** | Technical architecture and design | `docs/architecture.md` |
| **Project README** | Project overview and setup | `README.md` |
| **API Docs** | Interactive API documentation | `http://localhost:8000/docs` |
| **Infrastructure** | Azure deployment guide | `infrastructure/terraform/README.md` |

---

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

---

## 🐛 Common Issues

### Docker containers won't start
- Check if ports 3000, 5432, 6379, 8000 are available
- Run `docker-compose down -v` to clean up volumes
- Rebuild: `docker-compose up --build --force-recreate`

### Database connection errors
- Ensure PostgreSQL is running
- Check `DATABASE_URL` in `.env`
- Verify database exists: `psql -U postgres -l`

### Frontend can't connect to backend
- Ensure backend is running on port 8000
- Check `VITE_API_URL` in frontend `.env`
- Check browser console for CORS errors

---

## 📞 Support & Resources

### Documentation
- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [React Docs](https://react.dev/)
- [Material-UI](https://mui.com/)
- [Azure Docs](https://docs.microsoft.com/azure/)

### G-Cloud Framework
- [G-Cloud Framework Information](https://www.gov.uk/government/collections/g-cloud-frameworks)
- [Digital Marketplace](https://www.digitalmarketplace.service.gov.uk/)

---

## 🎉 You're All Set!

The foundation is built and ready for development. The next step is to implement the Phase 1 MVP features:

1. **Week 1-2**: Backend API endpoints and validation engine
2. **Week 3-4**: Frontend UI components and pages
3. **Week 4**: Integration testing and deployment

Each component is clearly structured, documented, and ready to be built incrementally.

---

**Happy Coding! 🚀**

For questions or issues, refer to the comprehensive documentation in the `docs/` directory.

