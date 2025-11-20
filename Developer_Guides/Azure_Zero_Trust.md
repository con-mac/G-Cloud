## Azure Zero Trust & Least Privilege Matrix

This document captures the minimum roles, identities, and policies required to run the Azure deployment securely while integrating with SharePoint Online and Microsoft Graph.

---

### 1. Guiding Principles

- **Verify explicitly**: Require Entra ID authentication for every operator, workload, and automation.
- **Use least privilege**: Scope every role assignment to the smallest resource (subscription → resource group → individual resource).
- **Assume breach**: Isolate workloads, rotate secrets, and monitor continuously.
- **Prefer managed identities**: Avoid long-lived keys. When OAuth secrets are unavoidable (SharePoint app), store them in Key Vault with access policies.

---

### 2. Identities & Roles

| Identity | Purpose | Scope | Role Assignments |
| --- | --- | --- | --- |
| **Resource group service principal** (`gcloud-automation-deployer`) | CI/CD automation deploying infrastructure | Resource group (`gcloud-automation-rg`) | `Contributor` (temporary) during provisioning, revert to `Website Contributor`, `Storage Blob Data Contributor`, `Key Vault Secrets Officer` scoped to needed resources |
| **API Function managed identity** (`gcloud-automation-api`) | FastAPI runtime talking to storage & Key Vault | Storage account, Key Vault | `Storage Blob Data Contributor` (sharepoint, uploads, templates containers), `Key Vault Secrets User` |
| **PDF Function managed identity** (`gcloud-automation-pdf`) | PDF conversion runtime with container image | Storage account | `Storage Blob Data Contributor` on `output` container only |
| **Static Web App managed identity** | Optional if using API management or calling Graph directly | API Management scope | `API Management Service Contributor` if needed |
| **Operations break-glass account** | Manual emergency fixes | Subscription | `Owner`, protected by Conditional Access & PIM |
| **Azure DevOps/GitHub OIDC principal** | Federated deploys | Resource group | Same as CI/CD principal but time-bound via workload identity federation |

---

### 3. Storage RBAC Details

- Assign **container-level** permissions using Azure RBAC:
  ```bash
  az role assignment create \
    --assignee <principal-id> \
    --role "Storage Blob Data Contributor" \
    --scope "/subscriptions/<sub>/resourceGroups/gcloud-automation-rg/providers/Microsoft.Storage/storageAccounts/gcloudautomationprodsa/blobServices/default/containers/sharepoint"
  ```
- Disable public access on the storage account; use private endpoints if hosting inside virtual network (see Azure Storage security guidance).
- Enable Storage account firewall to allow traffic only from Function outbound IPs or VNet integration.

---

### 4. Key Vault Controls

- Grant only `get` and `list` permissions to function managed identities.
- Use Key Vault RBAC (preview) or access policies; prefer RBAC for per-secret controls.
- Enable Key Vault logging to Log Analytics.
- Use Key Vault references in Function App settings to avoid storing secrets in app configuration.

---

### 5. SharePoint & Graph Permissions

1. **Entra ID app registration** (`gcloud-automation-graph-app`)
   - API permissions: `Sites.Selected`, `Files.ReadWrite.All` (delegated avoided; use application permissions).
   - Admin consent granted at tenant level.
2. **SharePoint site scope**:
   ```bash
   az rest --method POST \
     --uri https://graph.microsoft.com/v1.0/sites/{site-id}/permissions \
     --body '{
       "roles": ["write"],
       "grantedToIdentities": [{
         "application": {
           "id": "<CLIENT_ID>",
           "displayName": "gcloud-automation-graph-app"
         }
       }]
     }'
   ```
3. Store client secret / certificate in Key Vault. Rotate every 6 months or use certificate auth.

---

### 6. Network Isolation

- Enable **VNet integration** for both Function Apps; place storage account behind Private Endpoint.
- If using Azure API Management, enable **internal** mode and expose via Application Gateway / Front Door.
- Force HTTPS across all endpoints; configure HSTS on Static Web App custom domain.

---

### 7. Monitoring & Alerting

- Azure Monitor alert rules:
  - Function errors > 5 in 5 minutes (severity 2).
  - Unauthorized Key Vault access attempts.
  - Blob storage delete operations.
- Stream logs to Log Analytics workspace; integrate with Microsoft Sentinel if available.
- Enable Defender for Cloud recommendations for Functions, Storage, Key Vault.

---

### 8. Deployment Governance

- Use Azure Policy to enforce:
  - No public network access on storage accounts.
  - Key Vault firewall enabled.
  - Function App HTTPS only.
  - Diagnostic settings configured.
- Deploy via GitHub Actions with OIDC; no long-lived deploy keys.
- Require pull-request approvals with CODEOWNERS for `Developer_Guides`, `backend`, `frontend`, `scripts`.

---

### 9. Operational Runbook (Least Privilege)

| Task | Role Required | Notes |
| --- | --- | --- |
| Redeploy backend function | `Function App Contributor` on API function | Access only to production environment pipeline |
| Update PDF container image | `AcrPush` on ACR + `Function App Contributor` on PDF function | Use build pipeline identity |
| Rotate SharePoint secret | `Key Vault Secrets Officer` (temporary) | Update Key Vault secret, confirm version |
| View logs | `Log Analytics Reader` | Assign to support teams |
| Restore blob | `Storage Blob Data Contributor` scoped to container | Use versioning / soft-delete restore |

---

### 10. Compliance Checklist

- [ ] MFA enforced for all administrators (Conditional Access baseline policy).
- [ ] Privileged Identity Management enabled for Owner/Contributor roles.
- [ ] Secrets rotated on schedule; monitored via Key Vault expiration alerts.
- [ ] Pen-test the API endpoints annually; integrate WAF (Front Door Premium) with ruleset.
- [ ] Document data flows and DPIA if SharePoint hosts personal data.

Following this matrix ensures the Azure deployment operates on a true least-privilege model while maintaining compatibility with the existing SharePoint integration and PDF generation workflows.

