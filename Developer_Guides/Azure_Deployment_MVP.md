## Azure Deployment Runbook (MVP Parity)

This guide recreates the current AWS MVP architecture on Azure. Follow the steps in order to provision, deploy, verify, and operate the FastAPI + React service description tool and its PDF converter in Azure.

---

### 1. Architecture Mapping

| Requirement | AWS Component | Azure Equivalent |
| --- | --- | --- |
| FastAPI service (document parsing, SharePoint sync) | Lambda + API Gateway | Azure Functions (Python), HTTP trigger behind Azure API Management (optional) |
| PDF converter worker | Lambda (container) | Azure Functions (containerised) or Azure Container Apps job |
| Static React frontend | S3 + CloudFront | Azure Static Web Apps (or Storage static website + Azure Front Door) |
| Document storage (templates, generated docs) | S3 buckets | Azure Storage Account → Blob containers (`sharepoint`, `output`, `uploads`, `templates`) |
| Secrets / configuration | Lambda env vars | Azure Key Vault + App Settings |
| IAM policies | IAM roles | Managed identities + RBAC (see zero trust guide) |
| SharePoint integration | Graph API via app registration | Same (re-use app registration, or create new Entra ID app) |

---

### 2. Prerequisites

1. Azure subscription with owner/contributor rights to a dedicated resource group.
2. Azure CLI ≥ 2.60 with `azure-functions-core-tools` v4 (for Python publishing).
3. GitHub Actions or Azure DevOps agent with access to the repo.
4. Existing Microsoft 365 tenant & SharePoint site access; Entra ID app registration with `Sites.Selected` scope granted.

---

### 3. Provision Azure Resources

```bash
RESOURCE_GROUP=gcloud-automation-rg
LOCATION=uksouth
STORAGE_ACCOUNT=gcloudautomationprodsa
FUNCTION_PLAN=gcloud-automation-funcplan
API_FUNCTION=gcloud-automation-api
PDF_FUNCTION=gcloud-automation-pdf
STATIC_WEB_APP=gcloud-automation-web
KEYVAULT=gcloud-automation-kv

az group create --name $RESOURCE_GROUP --location $LOCATION

# Storage (Hot tier, hierarchical namespace off)
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false

az storage container create --account-name $STORAGE_ACCOUNT --name sharepoint --auth-mode login
az storage container create --account-name $STORAGE_ACCOUNT --name output --auth-mode login
az storage container create --account-name $STORAGE_ACCOUNT --name uploads --auth-mode login
az storage container create --account-name $STORAGE_ACCOUNT --name templates --auth-mode login

# Consumption function plan (Linux)
az functionapp plan create \
  --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_PLAN \
  --location $LOCATION \
  --is-linux \
  --number-of-workers 1 \
  --sku Y1

# API Function (Python)
az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $FUNCTION_PLAN \
  --runtime python \
  --functions-version 4 \
  --name $API_FUNCTION \
  --storage-account $STORAGE_ACCOUNT \
  --os-type Linux

# PDF Function (container)
az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $FUNCTION_PLAN \
  --name $PDF_FUNCTION \
  --storage-account $STORAGE_ACCOUNT \
  --functions-version 4 \
  --deployment-container-image-name <ACR_LOGIN_SERVER>/pdf-converter:latest \
  --assign-identity

# Static Web App
az staticwebapp create \
  --name $STATIC_WEB_APP \
  --resource-group $RESOURCE_GROUP \
  --location westeurope \
  --source . \
  --app-location frontend \
  --output-location dist \
  --login-with-github

# Key Vault
az keyvault create --name $KEYVAULT --resource-group $RESOURCE_GROUP --location $LOCATION
```

> **Notes**
> - Container image for the PDF function should contain LibreOffice or `docx2pdf` dependencies (reuse current Dockerfile with Azure Functions base).
> - For Static Web Apps, supply GitHub token during `az staticwebapp create` or create via portal to connect CI pipeline automatically.

---

### 4. Configuration Management

1. Store sensitive values in Key Vault:
   ```bash
   az keyvault secret set --vault-name $KEYVAULT --name "SharePoint-App-ClientId" --value <GUID>
   az keyvault secret set --vault-name $KEYVAULT --name "SharePoint-App-ClientSecret" --value <SECRET>
   az keyvault secret set --vault-name $KEYVAULT --name "SharePoint-TenantId" --value <TENANT_ID>
   az keyvault secret set --vault-name $KEYVAULT --name "SharePoint-SiteId" --value <SITE_ID>
   ```
2. Grant managed identities access:
   ```bash
   az keyvault set-policy --name $KEYVAULT --resource-group $RESOURCE_GROUP \
     --object-id $(az functionapp identity show -g $RESOURCE_GROUP -n $API_FUNCTION --query principalId -o tsv) \
     --secret-permissions get list

   az keyvault set-policy --name $KEYVAULT --resource-group $RESOURCE_GROUP \
     --object-id $(az functionapp identity show -g $RESOURCE_GROUP -n $PDF_FUNCTION --query principalId -o tsv) \
     --secret-permissions get list
   ```
3. Configure function app settings:
   ```bash
   az functionapp config appsettings set -g $RESOURCE_GROUP -n $API_FUNCTION --settings \
     STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT \
     SHAREPOINT_CONTAINER=sharepoint \
     OUTPUT_CONTAINER=output \
     UPLOADS_CONTAINER=uploads \
     TEMPLATES_CONTAINER=templates \
     KEYVAULT_URI=https://$KEYVAULT.vault.azure.net

   az functionapp config appsettings set -g $RESOURCE_GROUP -n $PDF_FUNCTION --settings \
     STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT \
     OUTPUT_CONTAINER=output \
     KEYVAULT_URI=https://$KEYVAULT.vault.azure.net
   ```

---

### 5. Backend Deployment (FastAPI Function)

1. **Convert ASGI app to Azure Function**  
   Wrap the existing FastAPI app with `azure.functions.AsgiMiddleware` inside `function_app/__init__.py`:
   ```python
   import azure.functions as func
   from app.main import api  # FastAPI instance

   app = func.AsgiFunctionApp(app=api)
   ```
2. **Structure**  
   ```
   backend/
     function_app/
       __init__.py
       host.json
       local.settings.json
       requirements.txt (runtime-only deps)
   ```
3. **Publish**
   ```bash
   cd backend/function_app
   python -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   func azure functionapp publish $API_FUNCTION --python
   ```
4. **API Management (optional)**  
   For throttling and network policies, deploy Azure API Management and import the Function app as an API.

---

### 6. PDF Converter Deployment

1. **Containerise**  
   Reuse `backend/pdf_converter/Dockerfile` and ensure `requirements.txt` includes `docx2pdf`, `python-docx`, and LibreOffice packages (for Linux).
2. **Push to ACR**
   ```bash
   ACR=gcloudautomationacr
   az acr create -g $RESOURCE_GROUP -n $ACR --sku Basic
   az acr build --registry $ACR --resource-group $RESOURCE_GROUP \
     --image pdf-converter:latest backend/pdf_converter
   ```
3. **Grant runtime permissions**  
   Assign `Storage Blob Data Contributor` to the PDF function’s managed identity on the storage account:
   ```bash
   az role assignment create \
     --assignee $(az functionapp identity show -g $RESOURCE_GROUP -n $PDF_FUNCTION --query principalId -o tsv) \
     --role "Storage Blob Data Contributor" \
     --scope $(az storage account show -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT --query id -o tsv)
   ```
4. **Configure trigger**  
   - Option A: HTTP trigger (direct call from API function) – mimic Lambda integration.  
   - Option B: Queue-triggered (API drops message on `pdf-jobs` queue). If using queue, grant queue permissions.
5. **Publish**  
   ```bash
   az functionapp config container set \
     --name $PDF_FUNCTION \
     --resource-group $RESOURCE_GROUP \
     --docker-custom-image-name $ACR.azurecr.io/pdf-converter:latest \
     --docker-registry-server-url https://$ACR.azurecr.io

   az acr update -n $ACR --admin-enabled true
   az functionapp config appsettings set -g $RESOURCE_GROUP -n $PDF_FUNCTION --settings \
     DOCKER_REGISTRY_SERVER_URL=https://$ACR.azurecr.io \
     DOCKER_REGISTRY_SERVER_USERNAME=$(az acr credential show -n $ACR --query username -o tsv) \
     DOCKER_REGISTRY_SERVER_PASSWORD=$(az acr credential show -n $ACR --query passwords[0].value -o tsv)
   ```

---

### 7. Frontend Deployment

1. Ensure `frontend/.env.production` points to the Function endpoint (e.g. `VITE_API_BASE=https://<STATIC_WEB_APP>.azurestaticapps.net/api` or APIM URL).
2. For Static Web Apps with GitHub workflow:
   - The `az staticwebapp create` command generates `.github/workflows/azure-static-web-apps.yml`.
   - Ensure the build command is `npm ci && npm run build` with `app_location: "frontend"` and `output_location: "dist"`.
3. Manual deployment (optional):
   ```bash
   npm install
   npm run build
   az storage blob upload-batch \
     --account-name $STORAGE_ACCOUNT \
     --source frontend/dist \
     --destination \$web

   az cdn endpoint purge --resource-group $RESOURCE_GROUP --profile-name gcloud-automation-cdn --name gcloud-automation-endpoint --content-paths "/*"
   ```

---

### 8. SharePoint Integration

1. Use the existing Entra ID app registration; ensure redirect URIs and certificates remain valid.
2. Grant `Sites.Selected` for delegated access and assign the specific SharePoint site via:
   ```bash
   az rest --method POST \
     --uri https://graph.microsoft.com/v1.0/sites/{site-id}/permissions \
     --body '{
       "roles": ["write"],
       "grantedToIdentities": [{"application": {"id": "<app-client-id>"}}]
     }'
   ```
3. Store SharePoint credentials in Key Vault and use managed identity to retrieve them at runtime.

---

### 9. Automated Deployment (GitHub Actions)

```yaml
name: Azure Deploy
on:
  push:
    branches: [ main ]

jobs:
  build_and_deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install backend deps
        run: |
          cd backend/function_app
          pip install -r requirements.txt

      - name: Run backend tests
        run: pytest backend/tests

      - name: Publish API Function
        uses: Azure/functions-action@v1
        with:
          app-name: ${{ secrets.AZURE_FUNCTION_APP }}
          package: backend/function_app

      - name: Build frontend
        run: |
          cd frontend
          npm ci
          npm run build

      - name: Deploy Static Web App
        uses: Azure/static-web-apps-deploy@v1
        with:
          app_location: "frontend"
          output_location: "dist"
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}

      - name: Deploy PDF Function Container
        run: |
          az acr build --registry ${{ secrets.AZURE_ACR_NAME }} --image pdf-converter:latest backend/pdf_converter
          az functionapp config container set --name ${{ secrets.AZURE_PDF_FUNCTION }} --resource-group ${{ secrets.AZURE_RG }} --docker-custom-image-name ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/pdf-converter:latest
```

Populate secrets via GitHub environments. Use federated credentials to avoid static passwords.

---

### 10. Validation & Smoke Tests

1. `pytest` suite (see unit test section) passes in CI.
2. Manual smoke after deployment:
   - Create new proposal → confirm features/benefits without numbering.
   - Upload template → confirm storage in `templates` container.
   - Generate Word & PDF → confirm blobs exist in `sharepoint` and `output`.
   - Download PDF → ensure HTTP 200.
   - Check Azure Monitor logs for both functions (no errors in last 15 mins).

---

### 11. Rollback

- **Functions**: `func azure functionapp publish` with previous artefact or redeploy from last successful pipeline artefact.
- **Static Web App**: redeploy prior commit (`az staticwebapp upload` with previous build or rollback via GitHub Actions workflow run).
- **Storage**: versioning can be enabled on the storage account to recover deleted blobs.

---

### 12. Cost & Observability Considerations

- Enable Azure Monitor Application Insights on both function apps (`az monitor app-insights component create`).
- Configure log analytics workspace and diagnostic settings for storage and static web app.
- Use Azure Front Door or Traffic Manager for global caching if required.
- Apply auto-scale rules if converting to Premium function plan later.

---

### 13. Unit Tests (see `backend/tests/azure` folder)

- `test_sharepoint_prefix_strip.py`: ensures number prefix stripping remains deterministic.
- `test_blob_path_resolver.py`: validates Azure path computation for generated docs.
- `test_pdf_queue_contract.py`: tests payload schema for PDF conversion trigger.
- `test_healthcheck.py`: ensures `/health` returns 200 under Azure Function context.

Run with:
```bash
pytest backend/tests/azure -q
```

---

### 14. Next Steps

- Implement Infrastructure as Code (Bicep or Terraform) for repeatable provisioning.
- Wire Azure Front Door custom domain + HTTPS certificate.
- Configure Conditional Access & private endpoints (see Zero Trust guide).
- Migrate runtime secrets into Azure Key Vault references in Function App settings.

This runbook mirrors the AWS MVP in Azure while keeping the deployment pipeline, monitoring, and compliance ready for production.

