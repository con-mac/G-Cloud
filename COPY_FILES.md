# Files to Copy from Main Repository

This document lists the files that need to be copied from the main repository to complete the PA deployment structure.

## Backend Files to Copy

### Core Services
- [ ] `backend/app/services/pricing_document_generator.py` - Modify for SharePoint
- [ ] `backend/app/services/questionnaire_parser.py` - Should work as-is
- [ ] `backend/app/core/config.py` - Update for SharePoint config

### API Routes (Already created with placeholders)
- [x] `backend/app/api/routes/templates.py` - Created with placeholder
- [x] `backend/app/api/routes/proposals.py` - Created with placeholder
- [x] `backend/app/api/routes/sharepoint.py` - Created with placeholder
- [x] `backend/app/api/routes/questionnaire.py` - Created with placeholder
- [x] `backend/app/api/routes/analytics.py` - Created with placeholder

### Utilities
- [ ] Copy validation utilities if needed
- [ ] Copy any helper functions

## Frontend Files to Copy

### Pages
- [ ] `frontend/src/pages/ServiceDescriptionForm.tsx` - Update auth for MSAL
- [ ] `frontend/src/pages/ProposalEditor.tsx` - Update auth
- [ ] `frontend/src/pages/ProposalsList.tsx` - Update auth
- [ ] `frontend/src/pages/CreateProposal.tsx` - Update auth
- [ ] `frontend/src/pages/QuestionnairePage.tsx` - Update auth
- [ ] `frontend/src/pages/AdminDashboard.tsx` - Update auth
- [ ] `frontend/src/pages/QuestionnaireAnalytics.tsx` - Update auth

### Services
- [ ] `frontend/src/services/proposals.ts` - Should work as-is
- [ ] `frontend/src/services/sharepointApi.ts` - Update API base URL
- [ ] `frontend/src/services/questionnaireApi.ts` - Should work as-is
- [ ] `frontend/src/services/analyticsApi.ts` - Should work as-is
- [ ] `frontend/src/services/api.ts` - Update for private endpoints

### Auth
- [ ] Create `frontend/src/services/auth.ts` - MSAL integration (NEW)
- [ ] Update `frontend/src/App.tsx` - Add MSAL provider

### Configuration
- [ ] `frontend/package.json` - Add @azure/msal-browser and @azure/msal-react
- [ ] `frontend/vite.config.ts` - Update for production build
- [ ] `frontend/.env.production` - Update with actual values

## Templates and Docs
- [ ] `docs/service_description_template.docx` - Copy to backend/docs/
- [ ] `docs/PA GC15 Pricing Doc SERVICE TITLE.docx` - Copy to backend/docs/
- [ ] `docs/RM1557.15-G-Cloud-question-export (1).xlsx` - Copy to backend/docs/

## Notes

1. **SharePoint Integration**: All files marked with "PLACEHOLDER" need SharePoint Graph API implementation
2. **Authentication**: Frontend needs MSAL integration for Microsoft 365 SSO
3. **API URLs**: Update all API base URLs to use private endpoints
4. **Environment Variables**: Use config templates and fill in actual values

## Implementation Order

1. Copy essential service files (questionnaire_parser, pricing_document_generator)
2. Copy frontend pages and update auth
3. Implement SharePoint integration in sharepoint_online.py
4. Update document_generator to use SharePoint
5. Test end-to-end flow

