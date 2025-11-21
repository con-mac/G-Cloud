# G-Cloud Proposal Automation System - Requirements Document

**Version:** 1.0.0  
**Last Updated:** 28 October 2025  
**Status:** Initial Draft  

---

## 1. Executive Summary

This document outlines the requirements for a G-Cloud Proposal Automation System designed to streamline the creation, validation, and management of G-Cloud framework proposals and renewals. The system will reduce manual labour, ensure compliance with G-Cloud requirements, and provide change management capabilities.

---

## 2. Background

The G-Cloud (Government Cloud) framework is a UK government procurement system for cloud computing services. Suppliers must submit detailed service descriptions with specific sections that meet strict requirements including:
- Word count constraints (minimum and maximum)
- Mandatory field completion
- Specific data formats
- Compliance with framework guidelines

Currently, this process is highly manual, error-prone, and time-consuming.

---

## 3. Business Objectives

### 3.1 Primary Goals
1. **Reduce Manual Labour**: Automate word counting, validation, and compliance checking
2. **Ensure Quality**: Validate all sections before submission to prevent rejections
3. **Track Progress**: Monitor proposal completion status and alert on approaching deadlines
4. **Maintain History**: Enable review of previous proposals for consistency and learning
5. **Enable Collaboration**: Support multiple users working on different sections with change tracking

### 3.2 Success Metrics
- Reduce proposal preparation time by 50%
- Achieve 100% validation coverage before submission
- Zero submissions rejected due to formatting/compliance issues
- Enable tracking of all changes with full audit trail

---

## 4. Functional Requirements

### 4.1 Proposal Management

#### FR-1.1: Proposal Creation
- System shall allow users to create new G-Cloud proposals
- System shall support both fresh proposals and renewals
- System shall provide templates based on G-Cloud framework versions
- System shall allow users to clone previous proposals as starting points

#### FR-1.2: Section Structure
- System shall organize proposals into sections matching G-Cloud requirements
- System shall support the following section types:
  - Service Name and Summary
  - Service Features and Benefits
  - Pricing Information
  - Terms and Conditions
  - User Support
  - Onboarding and Offboarding
  - Data Management and Security
  - Additional sections as per G-Cloud framework

#### FR-1.3: Proposal Status
- System shall track proposal status: Draft, In Review, Ready for Submission, Submitted, Approved, Rejected
- System shall show overall completion percentage
- System shall display section-level completion status

### 4.2 Validation Engine

#### FR-2.1: Word Count Validation
- System shall count words in real-time for each section
- System shall enforce minimum word count requirements
- System shall enforce maximum word count requirements
- System shall display word count with visual indicators:
  - Red: Below minimum or above maximum
  - Amber: Within range but approaching limits (±10%)
  - Green: Comfortably within range
- System shall exclude common formatting elements from word count (headings, bullet points markers)

#### FR-2.2: Data Type Validation
- System shall validate data types for specific fields:
  - Text fields (free text with character limits)
  - Numeric fields (prices, quantities)
  - Email addresses
  - URLs
  - Dates
  - Phone numbers
- System shall show inline validation errors with clear messages
- System shall prevent invalid data types from being saved

#### FR-2.3: Mandatory Field Validation
- System shall identify and mark mandatory sections
- System shall prevent submission if mandatory sections are incomplete
- System shall provide a pre-submission validation report
- System shall highlight all validation issues before submission

#### FR-2.4: Business Rule Validation
- System shall support configurable validation rules
- System shall validate cross-section dependencies
- System shall check for consistency across related sections
- System shall validate against G-Cloud framework-specific requirements

### 4.3 Deadline Management

#### FR-3.1: Deadline Setting
- System shall allow setting proposal submission deadlines
- System shall support multiple milestone dates (internal review, final submission, etc.)
- System shall display time remaining for each deadline

#### FR-3.2: Notification System
- System shall send notifications at configurable intervals:
  - 30 days before deadline
  - 14 days before deadline
  - 7 days before deadline
  - 3 days before deadline
  - 1 day before deadline
- System shall support email notifications
- System shall provide in-app notification dashboard
- System shall send notifications for incomplete sections approaching deadline

### 4.4 Change Management

#### FR-4.1: Version Control
- System shall track all changes to proposal sections
- System shall record timestamp, user, and modified content for each change
- System shall allow viewing of change history per section
- System shall enable comparison between versions (diff view)
- System shall support rollback to previous versions

#### FR-4.2: Section Locking
- System shall lock sections when a user is actively editing
- System shall show which user is editing which section
- System shall release locks after period of inactivity
- System shall allow administrators to force unlock sections

#### FR-4.3: Audit Trail
- System shall maintain immutable audit log of all changes
- System shall record: who, what, when, from where (IP address)
- System shall allow filtering and searching audit logs
- System shall support audit log export for compliance

### 4.5 Previous Proposal Review

#### FR-5.1: Proposal Archive
- System shall store all historical proposals
- System shall maintain original submitted versions
- System shall allow searching proposals by date, status, or content
- System shall provide read-only access to archived proposals

#### FR-5.2: Comparison Features
- System shall allow side-by-side comparison of proposals
- System shall highlight differences between proposals
- System shall enable copying sections from previous proposals
- System shall show proposal evolution over time

### 4.6 Document Integration

#### FR-6.1: SharePoint Integration
- System shall connect to Microsoft SharePoint via Graph API
- System shall read existing G-Cloud documents from SharePoint
- System shall support OAuth authentication for SharePoint
- System shall maintain sync status for SharePoint documents

#### FR-6.2: Document Import/Export
- System shall import existing Word documents (.docx)
- System shall parse document structure and extract sections
- System shall export proposals to Word format for submission
- System shall maintain original formatting where possible
- System shall support PDF export for previewing

#### FR-6.3: Document Migration
- System shall provide migration tool for existing proposals
- System shall validate migrated content against current rules
- System shall create migration report showing any issues
- System shall allow batch import of multiple documents

### 4.7 User Management

#### FR-7.1: Authentication
- System shall integrate with Azure Active Directory
- System shall support Single Sign-On (SSO)
- System shall enforce multi-factor authentication (MFA) for production
- System shall maintain secure session management

#### FR-7.2: Authorization
- System shall implement role-based access control (RBAC):
  - **Viewer**: Read-only access to proposals
  - **Editor**: Create and edit proposals
  - **Reviewer**: Review and approve proposals
  - **Administrator**: Full system access and configuration
- System shall enforce permissions at section level
- System shall support custom role definitions

#### FR-7.3: User Activity
- System shall show recent user activity dashboard
- System shall display active users and their current work
- System shall track user contribution to proposals

### 4.8 Reporting and Analytics

#### FR-8.1: Progress Reports
- System shall generate proposal completion reports
- System shall show section-level progress across all proposals
- System shall identify bottlenecks and overdue sections

#### FR-8.2: Validation Reports
- System shall produce validation summary reports
- System shall show most common validation failures
- System shall track validation trends over time

#### FR-8.3: Dashboard
- System shall provide overview dashboard showing:
  - Active proposals and their status
  - Upcoming deadlines
  - Recent changes
  - Validation issues requiring attention
  - User activity

---

## 5. Non-Functional Requirements

### 5.1 Performance

#### NFR-1.1: Response Time
- System shall load proposal pages within 2 seconds
- System shall perform real-time validation within 500ms
- System shall handle document uploads up to 50MB within 30 seconds

#### NFR-1.2: Scalability
- System shall support minimum 100 concurrent users
- System shall handle 1000+ proposals without performance degradation
- System shall scale horizontally in Azure environment

### 5.2 Security

#### NFR-2.1: Data Protection
- System shall encrypt all data at rest using Azure Storage encryption
- System shall encrypt all data in transit using TLS 1.3
- System shall store all secrets in Azure Key Vault
- System shall implement GDPR compliance for user data

#### NFR-2.2: Access Control
- System shall enforce principle of least privilege
- System shall log all access to sensitive data
- System shall implement rate limiting on API endpoints
- System shall protect against common vulnerabilities (OWASP Top 10)

#### NFR-2.3: Audit and Compliance
- System shall maintain audit logs for minimum 7 years
- System shall provide audit trail for all data modifications
- System shall support compliance reporting
- System shall enable data export for regulatory requirements

### 5.3 Availability

#### NFR-3.1: Uptime
- System shall maintain 99.5% uptime during business hours (UK time)
- System shall implement automated health monitoring
- System shall provide status page for system health

#### NFR-3.2: Backup and Recovery
- System shall perform daily automated backups
- System shall retain backups for 90 days
- System shall enable point-in-time recovery
- System shall test disaster recovery procedures quarterly

### 5.4 Usability

#### NFR-4.1: User Interface
- System shall provide responsive design (desktop, tablet, mobile)
- System shall follow accessibility guidelines (WCAG 2.1 Level AA)
- System shall provide consistent user experience
- System shall include inline help and tooltips

#### NFR-4.2: Documentation
- System shall provide user documentation
- System shall include video tutorials for key features
- System shall maintain API documentation
- System shall provide administrator guide

### 5.5 Maintainability

#### NFR-5.1: Code Quality
- System shall maintain minimum 80% code test coverage
- System shall follow coding standards and best practices
- System shall use automated code quality checks
- System shall maintain clear separation of concerns

#### NFR-5.2: Monitoring
- System shall integrate with Azure Application Insights
- System shall track key performance metrics
- System shall alert on errors and anomalies
- System shall provide debugging and troubleshooting tools

---

## 6. Technical Architecture

### 6.1 Technology Stack

#### Frontend
- **Framework**: React 18+ with TypeScript
- **State Management**: Redux Toolkit or Zustand
- **UI Library**: Material-UI (MUI) or Ant Design
- **Rich Text Editor**: Draft.js or TipTap
- **Build Tool**: Vite
- **Testing**: Jest, React Testing Library

#### Backend
- **Framework**: Python FastAPI 0.100+
- **ORM**: SQLAlchemy
- **Validation**: Pydantic
- **Task Queue**: Celery with Redis
- **Testing**: Pytest

#### Database
- **Primary**: Azure SQL Database (PostgreSQL)
- **Cache**: Azure Redis Cache
- **Document Storage**: Azure Blob Storage

#### Infrastructure
- **Hosting**: Azure App Service
- **Authentication**: Azure Active Directory
- **Secrets**: Azure Key Vault
- **Monitoring**: Azure Application Insights
- **Notifications**: Azure Functions + SendGrid
- **CDN**: Azure Front Door

#### Integration
- **SharePoint**: Microsoft Graph API
- **Document Processing**: python-docx, pypandoc

### 6.2 Architecture Pattern
- **Pattern**: Three-tier architecture
- **API Design**: RESTful with OpenAPI specification
- **Authentication**: JWT tokens with Azure AD integration
- **Deployment**: Docker containers on Azure App Service

---

## 7. Data Model Overview

### 7.1 Core Entities

#### Proposal
- id (UUID)
- title (string)
- framework_version (string)
- status (enum)
- deadline (datetime)
- created_by (user_id)
- created_at (datetime)
- modified_at (datetime)
- completion_percentage (float)

#### Section
- id (UUID)
- proposal_id (FK)
- section_type (enum)
- title (string)
- content (text)
- order (integer)
- word_count (integer)
- validation_status (enum)
- is_mandatory (boolean)
- last_modified_by (user_id)
- last_modified_at (datetime)

#### ValidationRule
- id (UUID)
- section_type (enum)
- rule_type (enum)
- parameter (JSON)
- error_message (string)
- severity (enum: error, warning)
- is_active (boolean)

#### ChangeHistory
- id (UUID)
- section_id (FK)
- user_id (FK)
- changed_at (datetime)
- old_content (text)
- new_content (text)
- change_type (enum)
- ip_address (string)

#### User
- id (UUID)
- azure_ad_id (string)
- email (string)
- full_name (string)
- role (enum)
- is_active (boolean)
- last_login (datetime)

#### Notification
- id (UUID)
- proposal_id (FK)
- user_id (FK)
- notification_type (enum)
- message (text)
- sent_at (datetime)
- read_at (datetime)
- is_sent (boolean)

---

## 8. Development Phases

### Phase 1: Foundation (MVP) - 4 weeks
**Goal**: Core proposal management and validation

**Deliverables**:
- Basic proposal CRUD operations
- Section-based structure
- Real-time word count validation
- Data type validation
- User authentication (Azure AD)
- Basic UI for proposal editing
- Deadline setting
- Completion status tracking

**Success Criteria**:
- Can create, edit, and view proposals
- Word count validation works in real-time
- All mandatory fields validated
- User can log in with Azure AD

### Phase 2: Integration - 3 weeks
**Goal**: SharePoint connectivity and document import

**Deliverables**:
- Microsoft Graph API integration
- Document import from SharePoint
- Document parsing (Word to structured data)
- Document export (structured data to Word)
- Azure Blob Storage integration
- Migration tool for existing documents

**Success Criteria**:
- Can connect to SharePoint
- Can import existing Word documents
- Parsed content matches original structure
- Can export proposals to Word format

### Phase 3: Change Management - 3 weeks
**Goal**: Version control and audit trail

**Deliverables**:
- Change history tracking
- Version comparison (diff view)
- Section locking mechanism
- Rollback functionality
- Comprehensive audit logging
- Change history UI

**Success Criteria**:
- All changes tracked with full details
- Can view differences between versions
- Can rollback to previous versions
- Audit trail is immutable and complete

### Phase 4: Notifications - 2 weeks
**Goal**: Alert system for deadlines

**Deliverables**:
- Azure Functions for scheduled notifications
- Email notification system (SendGrid)
- In-app notification dashboard
- Configurable notification rules
- Notification preferences per user

**Success Criteria**:
- Notifications sent at correct intervals
- Users receive emails and in-app alerts
- Can configure notification preferences

### Phase 5: Advanced Features - 4 weeks
**Goal**: Enhanced usability and analytics

**Deliverables**:
- Proposal comparison features
- Analytics dashboard
- Validation reports
- Progress tracking reports
- Proposal templates
- Bulk operations
- Advanced search

**Success Criteria**:
- Can compare multiple proposals
- Dashboard shows actionable insights
- Reports are accurate and useful
- Templates speed up proposal creation

### Phase 6: Polish and Optimisation - 2 weeks
**Goal**: Production readiness

**Deliverables**:
- Performance optimisation
- Comprehensive testing
- User documentation
- Administrator documentation
- Video tutorials
- Deployment automation
- Monitoring and alerting setup

**Success Criteria**:
- System meets all performance requirements
- Test coverage >80%
- Documentation complete
- Successfully deployed to production

---

## 9. Risk Assessment

### 9.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| SharePoint API limitations | High | Medium | Early proof of concept, fallback to manual upload |
| Document parsing accuracy | High | Medium | Extensive testing with real documents, manual review option |
| Azure service costs | Medium | Low | Cost monitoring, alerts, optimise resource usage |
| Performance with large documents | Medium | Medium | Implement pagination, lazy loading, optimise queries |
| Integration complexity | Medium | Medium | Start with simple integration, iterate |

### 9.2 Business Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| G-Cloud framework changes | High | Medium | Flexible validation rule engine, regular updates |
| User adoption | High | Low | User training, intuitive UI, clear benefits |
| Data migration issues | Medium | Medium | Thorough testing, phased migration, backup plans |
| Scope creep | Medium | Medium | Clear requirements, change control process |

---

## 10. Testing Strategy

### 10.1 Testing Types

#### Unit Testing
- Test coverage: >80%
- All validation rules tested independently
- All API endpoints tested
- Frontend components tested in isolation

#### Integration Testing
- API integration tests
- Database integration tests
- SharePoint integration tests
- Azure service integration tests

#### End-to-End Testing
- Complete user workflows
- Proposal creation to submission
- Document import and export
- Notification delivery

#### Performance Testing
- Load testing (100+ concurrent users)
- Stress testing
- Document upload performance
- Database query optimisation

#### Security Testing
- Penetration testing
- Authentication and authorisation testing
- Data encryption verification
- OWASP Top 10 vulnerability scanning

#### User Acceptance Testing
- Real users testing key workflows
- Feedback collection and incorporation
- Usability testing

---

## 11. Deployment Strategy

### 11.1 Environments
- **Development**: For active development and integration
- **Staging**: Production-like environment for final testing
- **Production**: Live environment for end users

### 11.2 CI/CD Pipeline
- **Source Control**: Git (GitHub/Azure DevOps)
- **CI Tool**: GitHub Actions or Azure Pipelines
- **Automated Testing**: Run on every commit
- **Automated Deployment**: Deploy to staging on merge to main
- **Production Deployment**: Manual approval required

### 11.3 Monitoring
- Application Insights for telemetry
- Log aggregation and analysis
- Alert rules for errors and performance issues
- Regular health checks

---

## 12. Maintenance and Support

### 12.1 Support Model
- **Tier 1**: User documentation and FAQs
- **Tier 2**: Support team for common issues
- **Tier 3**: Development team for complex issues

### 12.2 Maintenance Windows
- Scheduled maintenance: Monthly, Saturday 00:00-04:00 UK time
- Emergency maintenance: As required, with advance notification

### 12.3 Updates
- Security patches: Within 48 hours of availability
- Bug fixes: Bi-weekly release cycle
- New features: Monthly release cycle
- Framework updates: As G-Cloud framework changes

---

## 13. Future Enhancements

### Potential Future Features (Not in Current Scope)

1. **AI-Powered Features**
   - Content suggestions based on previous successful proposals
   - Automatic summary generation
   - Quality scoring and improvement recommendations

2. **Advanced Collaboration**
   - Real-time collaborative editing
   - Comments and discussions per section
   - Task assignment and workflow management

3. **Mobile App**
   - Native iOS and Android apps
   - Offline editing capabilities
   - Push notifications

4. **Advanced Analytics**
   - Success rate analysis
   - Benchmark against industry standards
   - Predictive analytics for submission success

5. **Integration with Other Systems**
   - CRM integration
   - Project management tools
   - Financial systems for pricing data

---

## 14. Glossary

- **G-Cloud**: Government Cloud framework for procuring cloud services in the UK
- **Proposal**: A submission to the G-Cloud framework describing a service
- **Section**: A distinct part of a proposal with specific requirements
- **Validation**: Checking content against rules and requirements
- **Azure AD**: Azure Active Directory, Microsoft's identity service
- **Graph API**: Microsoft's API for accessing Office 365 services including SharePoint
- **MVP**: Minimum Viable Product
- **RBAC**: Role-Based Access Control
- **JWT**: JSON Web Token for authentication
- **SSO**: Single Sign-On

---

## 15. Sign-off

This requirements document will be reviewed and updated regularly as the project progresses. All changes will be version controlled and require approval from key stakeholders.

**Document Control**:
- Reviews: Every 2 weeks during development
- Approval Required: For scope changes or new phases
- Distribution: All project team members

---

## 16. Appendices

### Appendix A: G-Cloud Section Types
(To be populated with specific G-Cloud framework sections)

### Appendix B: Validation Rules Reference
(To be populated with detailed validation rules)

### Appendix C: API Endpoints
(To be populated during development)

### Appendix D: Database Schema
(To be populated during development)

---

## 17. G-Cloud 15 Enhanced Features

### 17.1 Pricing Document Generation

#### FR-17.1.1: Automatic Pricing Doc Creation
- System shall automatically generate a generic Pricing Document when a new proposal folder and service name is created
- System shall use the "PA GC15 Pricing Doc SERVICE TITLE.docx" template
- System shall map the Service Name from the Service Description document to:
  - Cover Page title
  - Document title
- System shall follow the exact same mapping logic as the Service Description document generation
- System shall output the Pricing Document at the first step when folder and service name is created

#### FR-17.1.2: Pricing Doc Completion Message
- When a user selects "Complete and generate docs" in the Service Description workflow, system shall display an informational message:
  - "G-Cloud 15 will require a single rate card only this year that will be created and handled centrally. A generic pricing doc will be automatically generated. If your service requires a specific rate applied please contact the PA Bid Team"
- System shall continue with document generation after displaying this message
- System shall allow download of both Service Description and Pricing documents

### 17.2 Enhanced LOT Support

#### FR-17.2.1: New LOT Structure
- System shall support three LOT types:
  - **LOT 3**: Cloud Support Services
  - **LOT 2a**: IaaS and PaaS Services
  - **LOT 2b**: SaaS Services
- System shall follow the exact folder structure and naming convention from earlier requirements
- Folder structure format: `GCloud {version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/`
- System shall handle LOT values: "3", "2a", "2b"

### 17.3 G-Cloud Capabilities Questionnaire

#### FR-17.3.1: Questionnaire Workflow Integration
- System shall add a new workflow step: "G-Cloud Capabilities Questionnaire"
- System shall position this step after "Complete and generate documents" in the Service Description workflow
- System shall reference the Questionnaire step in the workflow diagram at the "Create New or Update" section
- System shall notify users of all logical workflow steps including the Questionnaire

#### FR-17.3.2: LOT-Specific Questions
- System shall load questions from the Excel document (`RM1557.15-G-Cloud-question-export (1).xlsx`)
- System shall focus on LOT 3, LOT 2a, and LOT 2b question sets
- System shall name question sets as "LOT 3", "LOT 2a", "LOT 2b" (ignoring other wording in sheet names)
- System shall map Service Name from the associated Service Description document to the 'Service Name' field in the questionnaire
- System shall ignore rows with Red filling in the second column (indicates not needed, already answered in SERVICE DESC)

#### FR-17.3.3: Question Types and Validation
- System shall support multiple question types:
  - **Radio buttons**: Single selection from options
  - **Checkboxes**: Multiple selections from options
  - **Text fields**: Free text input
  - **Textarea**: Multi-line text input
  - **List of text fields**: Multiple text inputs (e.g., features, benefits)
- System shall use helpers, hints, and advice from the Excel document to:
  - Determine correct variable type/format needed
  - Provide user guidance and validation rules
  - Display helpful summaries for users
- System shall validate inputs based on question type and constraints

#### FR-17.3.4: Questionnaire Pagination
- System shall paginate the questionnaire interface for better user experience
- System shall group questions by Section Name from the Excel sheets
- Each page/section shall display all questions belonging to that section
- System shall provide navigation between sections (Previous/Next buttons)
- System shall show progress indicator (e.g., "Section 1 of 5")
- System shall allow users to navigate to any section directly via section navigation

#### FR-17.3.4: Questionnaire State Management
- System shall allow users to save questionnaire responses as drafts
- System shall allow users to edit their answers before final submission
- System shall support a "locked" state where no further editing is permitted
- System shall determine the best output format for locked questionnaires (functional, not necessarily pretty)

### 17.4 Analytics Dashboard for Admin Users

#### FR-17.4.1: Visual Analytics
- System shall provide a hierarchical, top-down analytical view for admin users
- System shall display visualisations showing:
  - How many services chose option x, y, or z for each question
  - Distribution of answers across all services
  - Trends and patterns in responses

#### FR-17.4.2: Drill-Down Functionality
- System shall allow admins to drill into visualisations to see:
  - Which specific services answered what
  - Service-level detail for any aggregated view
  - Individual service responses

#### FR-17.4.3: Completion Tracking
- System shall identify and display services that haven't answered the questionnaire at all
- System shall show completion status for each service
- System shall provide filters to view:
  - Completed questionnaires
  - In-progress/draft questionnaires
  - Not started questionnaires

#### FR-17.4.4: Data Export
- System shall allow export of analytics data for further analysis
- System shall support export of individual service responses
- System shall maintain data integrity and audit trail for all analytics

---

**End of Requirements Document**

