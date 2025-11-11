## Copilot Studio Implementation Blueprint

### 1. Solution Overview

- **Copilot Studio** becomes the conversational front end, replacing the React form. Topics, adaptive cards, and generative answers guide users through creation, editing, and review of G-Cloud service descriptions.
- **Dataverse** stores proposals, drafts, features, benefits, attachments, and download URLs, replacing browser session storage. Records are surfaced to Power Apps dashboards.
- **Azure Functions (Python)** reuse the existing parsing and templating logic:
  - `ParseDocxFunction`: strips numbering/whitespace from Word documents and returns structured JSON.
  - `GenerateDocumentsFunction`: populates the template, writes the `.docx` to SharePoint, calls the PDF converter, and returns presigned download URLs.
- **PDF converter** runs as a container-based Azure Function (LibreOffice headless) or Azure Container App, always writing PDFs to the output document repository and returning a presigned SAS URL.
- **SharePoint Online** continues as the document store for templates and finished documents, with the existing folder structure (`GCloud {version}/Lot {n}/{Service}`).
- **Power Automate** orchestrates multi-step actions (parsing, saving drafts, generating final documents) via custom connectors to the Azure Functions.

### 2. Detailed Build Steps

1. **Provision Environment**
   - Create/enable Copilot Studio tenant with Dataverse.
   - Ensure Generative AI, custom connectors, and Power Automate are enabled.

2. **Dataverse Schema**
   - Tables: `Proposals`, `ServiceDescriptions`, `Features`, `Benefits`, `Attachments`.
   - Each proposal holds metadata (service name, lot, owner, version, status, Word/PDF URLs) and JSON payloads with stripped features/benefits.

3. **Azure Functions**
   - Deploy `ParseDocxFunction` and `GenerateDocumentsFunction` (HTTP-triggered, Azure AD protected).
   - Environment variables: `SHAREPOINT_SITE_URL`, `SHAREPOINT_DOC_LIB`, `OUTPUT_CONTAINER`, `PDF_CONVERTER_URL`.
   - Use managed identity for SharePoint and storage access.

4. **PDF Converter**
   - Deploy LibreOffice container as Azure Function or Container App.
   - Accept parameters: `word_s3_key`, `word_bucket`, `output_bucket`, `pdf_s3_key`.
   - Return `{ success, pdf_s3_key, pdf_url }` with a presigned SAS URL.

5. **Custom Connector**
   - Register OpenAPI definition covering both functions.
   - Configure OAuth 2.0 using Azure AD app registration.
   - Actions: `ParseDocx`, `GenerateDocuments`, `GetPresignedUrl` (optional).

6. **SharePoint Integrations**
   - Document library `ServiceDescriptions` with template stored under `templates/service_description_template.docx`.
   - Permissions aligned with existing solution.
   - Copilot SharePoint connector used for listing proposals and downloads.

7. **Power Automate Flows**
   - Flow A `ParseExistingDocument`: triggered from Copilot, calls parsing function, stores cleaned data to Dataverse.
   - Flow B `SubmitProposal`: saves structured input, calls document generation function, updates record with Word/PDF URLs.

8. **Copilot Topics & Generative Guidance**
   - Topic “Create Service Description”: captures metadata, features, benefits via adaptive card. Validates counts before calling Flow B.
   - Topic “Edit Existing Proposal”: lists user’s proposals (Dataverse view), calls Flow A, shows adaptive card for edits.
   - Topic “List Drafts/Completed”: Dataverse query; returns table with download links.
   - Knowledge base seeded with existing docs; generative responses explain number stripping and formatting rules.
   - Use conversation memory to pre-fill repeated prompts.

9. **Channels & Dashboards**
   - Publish Copilot to Teams and SharePoint (Copilot web channel).
   - Power Apps dashboard (Teams tab/SharePoint web part) using Dataverse tables for admin oversight.

10. **Security & Governance**
    - Azure AD groups controlling access to Copilot, Azure Functions, SharePoint.
    - Secrets managed via Key Vault / environment variables.
    - Logging with Application Insights; Power Platform monitoring for flows.

11. **Testing Strategy**
    - Unit tests for Azure Functions (python-docx parsing, templating, PDF invocation).
    - Power Automate Flow tester with mock payloads.
    - Copilot Studio test panel for conversation flows.
    - Manual verification: create, edit, generate, download Word/PDF documents; confirm PDF stored in output container.

### 3. Capability Mapping

| Current System | Copilot Studio Solution |
| --- | --- |
| React form with word-count validation | Copilot topics + adaptive cards + business rules |
| Session/local storage drafts | Dataverse draft records + conversation memory |
| Python regex stripping numbers | Azure Function reuse of `python-docx` logic |
| Word/PDF generation | Azure Function + SharePoint template + PDF converter |
| SharePoint storage & folders | Same libraries via Flow actions |
| Dashboard listing drafts/completed | Dataverse view via Power Apps + Copilot topic |
| Download Word/PDF | Presigned URLs returned from Functions and stored in Dataverse |

### 4. Next Steps Checklist

1. Deploy Azure Functions with existing parsing + templating code.
2. Stand up LibreOffice-based PDF converter in Azure.
3. Create custom connector and Power Automate flows.
4. Build Dataverse schema and seed with existing proposals.
5. Configure Copilot topics, adaptive cards, and generative instructions.
6. Publish Copilot to Teams/SharePoint; embed Dataverse dashboard.
7. Run full end-to-end tests (create → generate → download) and document acceptance.

