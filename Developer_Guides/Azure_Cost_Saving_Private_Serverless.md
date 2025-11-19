# Azure Cost-Saving Private Serverless Architecture

## Executive Summary

This document outlines a fully private, serverless architecture that eliminates all public internet endpoints while maintaining zero monthly base costs when the application is not in use. The solution leverages Azure Functions (Consumption plan) to serve both the React frontend and API, deployed in a shared App Service Environment with Private Endpoint connectivity.

**Key Benefits:**
- ✅ **Zero monthly cost when idle** (pay only during 6-week usage periods)
- ✅ **No public internet exposure** (all services via Private Endpoint)
- ✅ **Friendly private URLs** for PA users (e.g., `gcloud-app.pa.internal`)
- ✅ **Serverless architecture** (Functions Consumption plan)
- ✅ **Works with existing design** (minimal changes to current implementation)

---

## Architecture Overview

### Current Design (Maintained)
- **Backend API**: Azure Functions (Python) - FastAPI service
- **PDF Converter**: Azure Functions (Container) - LibreOffice conversion
- **Storage**: Azure Storage Account with Private Endpoint
- **Key Vault**: Azure Key Vault with Private Endpoint
- **Monitoring**: PA's existing Log Analytics and Application Insights

### New Addition (Frontend Function)
- **Frontend**: Azure Functions (Python) - Serves React SPA static files
- **Deployment**: Same shared App Service Environment
- **Plan**: Consumption (Y1) - pay per execution only

---

## How PA Users Access the Application Privately

### Access Flow

```
PA Corporate Network
    ↓
VPN / ExpressRoute / Private Link
    ↓
Azure Virtual Network (PA's VNet)
    ↓
Private DNS Zone (pa.internal)
    ↓
Private Endpoint (App Service Environment)
    ↓
Frontend Function (serves React SPA)
    ↓
API Function (FastAPI backend)
```

### Private URL Configuration

**Friendly Private URL**: `https://gcloud-app.pa.internal` or `https://gcloud-proposals.pa.internal`

**How it works:**
1. **Private DNS Zone** (`pa.internal`) created in PA's Azure subscription
2. **A Record** created pointing to App Service Environment Private Endpoint IP
3. **DNS Forwarding** configured on PA corporate DNS to resolve `*.pa.internal` to Azure Private DNS
4. Users on PA network (VPN/ExpressRoute) can access via friendly URL
5. **No public DNS** - resolution only works from within PA network

### Technical Details

**Private Endpoint IP**: Allocated from PA's VNet subnet (e.g., `10.0.1.100`)

**Private DNS Zone**: 
- Zone name: `pa.internal` (or `paconsulting.internal`)
- A record: `gcloud-app.pa.internal` → `10.0.1.100`
- Linked to PA's VNet for automatic resolution

**User Experience:**
- User connects to PA VPN or is on ExpressRoute-connected network
- Opens browser, navigates to `https://gcloud-app.pa.internal`
- DNS resolves to Private Endpoint IP (only works from PA network)
- HTTPS connection established to Function App via Private Endpoint
- Application loads normally, all API calls go to same Function App

---

## Serverless Frontend Implementation

### How Functions Serve React SPA

**Build Process** (unchanged):
```bash
cd frontend
npm run build  # Creates dist/ directory with static files
```

**Function Structure**:
```
frontend-function/
├── host.json
├── requirements.txt
├── function_app.py          # HTTP trigger serving static files
└── static/                  # React build output (dist/)
    ├── index.html
    ├── assets/
    │   ├── index-*.js
    │   └── index-*.css
    └── ...
```

**Function Code** (Python):
```python
import azure.functions as func
import os
from pathlib import Path

def main(req: func.HttpRequest) -> func.HttpResponse:
    # Get requested path
    path = req.params.get('path', '')
    if not path or path == '/':
        path = 'index.html'
    
    # Remove leading slash
    path = path.lstrip('/')
    
    # Security: prevent directory traversal
    if '..' in path:
        return func.HttpResponse("Forbidden", status_code=403)
    
    # Static file directory
    static_dir = Path(__file__).parent / 'static'
    file_path = static_dir / path
    
    # Check if file exists
    if not file_path.exists() or not file_path.is_file():
        # SPA routing: serve index.html for all non-file requests
        file_path = static_dir / 'index.html'
    
    # Read and serve file
    with open(file_path, 'rb') as f:
        content = f.read()
    
    # Determine content type
    content_type = 'text/html'
    if path.endswith('.js'):
        content_type = 'application/javascript'
    elif path.endswith('.css'):
        content_type = 'text/css'
    elif path.endswith('.json'):
        content_type = 'application/json'
    elif path.endswith('.png'):
        content_type = 'image/png'
    elif path.endswith('.jpg') or path.endswith('.jpeg'):
        content_type = 'image/jpeg'
    elif path.endswith('.svg'):
        content_type = 'image/svg+xml'
    
    return func.HttpResponse(
        content,
        mimetype=content_type,
        status_code=200
    )
```

**API Proxy** (same Function):
- Frontend Function also proxies `/api/*` requests to API Function
- Or frontend calls API Function directly via Private Endpoint URL
- Both Functions in same ASE = same network = fast communication

---

## Network Architecture (Fully Private)

### App Service Environment Configuration

**Shared ASE** (already exists):
- **Location**: PA's Virtual Network
- **Private Endpoint**: Enabled (no public VIP)
- **Subnet**: Dedicated subnet for ASE (e.g., `10.0.1.0/24`)
- **Private IP**: Allocated from subnet (e.g., `10.0.1.100`)

**Functions Deployment**:
- **Frontend Function**: Deployed to shared ASE
- **API Function**: Already deployed to shared ASE ✅
- **PDF Function**: Already deployed to shared ASE ✅
- **Plan**: Consumption (Y1) - shared across all Functions

### Private Endpoint Details

**App Service Environment Private Endpoint**:
- **Resource**: App Service Environment
- **Private IP**: `10.0.1.100` (example)
- **Subnet**: `10.0.1.0/24`
- **DNS Zone**: `pa.internal`
- **A Record**: `gcloud-app.pa.internal` → `10.0.1.100`

**Storage Account Private Endpoint** (already configured):
- Private IP in same VNet
- Functions access via Private Endpoint ✅

**Key Vault Private Endpoint** (already configured):
- Private IP in same VNet
- Functions access via Private Endpoint ✅

### User Network Connectivity

**Option 1: VPN (Point-to-Site or Site-to-Site)**
- PA users connect via Azure VPN Gateway
- Routes configured to resolve `*.pa.internal` via Private DNS
- Users access `https://gcloud-app.pa.internal`

**Option 2: ExpressRoute**
- PA corporate network connected via ExpressRoute
- Private peering configured
- DNS forwarding to Azure Private DNS Zone
- Users access `https://gcloud-app.pa.internal`

**Option 3: Azure Private Link Service** (if needed)
- Private Link Service created for App Service Environment
- PA network connects via Private Endpoint
- Same DNS resolution pattern

---

## Cost Analysis

### Current Architecture Costs (When Idle)

**Static Web App (Standard)**:
- Base cost: ~£7-9/month (even when unused)
- **Annual cost (idle)**: ~£84-108/year

**Azure Front Door** (if used):
- Base cost: ~£15-20/month
- **Annual cost (idle)**: ~£180-240/year

**Total Current (idle)**: ~£264-348/year

### Proposed Serverless Architecture Costs

**App Service Environment**:
- **Cost**: £0 (shared with other services - no incremental cost)
- **Note**: ASE base cost already allocated to other workloads

**Frontend Function (Consumption Plan)**:
- **When idle**: £0/month (no executions = no cost)
- **During 6-week usage**: Pay per execution
  - First 1M requests/month: Free
  - Additional: £0.16 per million executions
  - Estimated: <£5 for entire 6-week period

**API Function** (already Consumption):
- **When idle**: £0/month ✅
- **During usage**: Pay per execution (same as current)

**PDF Function** (already Consumption):
- **When idle**: £0/month ✅
- **During usage**: Pay per execution (same as current)

**Storage Account**:
- **Cost**: Same as current (no change)
- **Private Endpoint**: ~£0.01/hour = ~£7/month (but shared)

**Key Vault**:
- **Cost**: Same as current (no change)
- **Private Endpoint**: ~£0.01/hour = ~£7/month (but shared)

**Private DNS Zone**:
- **Cost**: ~£0.30/month per zone
- **A Records**: Free

### Cost Comparison

| Scenario | Current (Static Web App) | Proposed (Functions) | Savings |
|----------|-------------------------|---------------------|---------|
| **Idle (18 months)** | £126-162 | £0 | **£126-162** |
| **Active (6 weeks)** | £7-9 + usage | <£5 + usage | **£2-4** |
| **Annual Total** | £133-171 | <£5 | **~£130-170/year** |

**Key Point**: With 18-24 month idle periods, the savings are significant. The application costs nothing when not in use.

---

## Implementation Steps

### 1. Create Frontend Function

**Terraform Module** (similar to existing API Function):
```hcl
module "frontend_function" {
  source                    = "./modules/function_app"
  resource_group_name       = module.resource_group.name
  location                  = var.location
  name                      = format("%s-frontend", var.resource_naming_prefix)
  environment               = var.environment
  application_insights_id   = module.logging.application_insights_id
  application_insights_key  = module.logging.application_insights_instrumentation_key
  storage_account_tier      = var.storage_account_tier
  storage_account_replication = var.storage_account_replication
  # Use same ASE as API/PDF Functions
  app_service_environment_id = var.shared_ase_id
  tags = var.tags
}
```

### 2. Configure Private DNS Zone

**Terraform**:
```hcl
resource "azurerm_private_dns_zone" "pa_internal" {
  name                = "pa.internal"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pa_vnet" {
  name                  = "pa-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.pa_internal.name
  virtual_network_id    = var.pa_vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "gcloud_app" {
  name                = "gcloud-app"
  zone_name           = azurerm_private_dns_zone.pa_internal.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.ase_private_endpoint_ip]  # e.g., "10.0.1.100"
}
```

### 3. Deploy React SPA to Function

**Build Script**:
```bash
#!/bin/bash
# Build React app
cd frontend
npm run build

# Copy to Function directory
cp -r dist/* ../backend/frontend_function/static/

# Deploy Function
cd ../backend
func azure functionapp publish gcloud-frontend-prod
```

### 4. Configure DNS Forwarding (PA Network)

**On PA Corporate DNS**:
- Add conditional forwarder for `pa.internal` → Azure Private DNS Zone IP
- Or configure Azure Private DNS resolver in VNet

### 5. Update Frontend API Configuration

**Environment Variable** (Function App Settings):
```
VITE_API_URL=https://gcloud-api-prod.azurewebsites.net
```

Or use relative paths if both Functions in same domain:
```
VITE_API_URL=/api
```

Then Frontend Function proxies `/api/*` to API Function.

---

## Security Considerations

### Network Isolation
- ✅ **No public endpoints**: All services accessible only via Private Endpoint
- ✅ **VNet integration**: Functions in PA's VNet, isolated from internet
- ✅ **Private DNS**: Resolution only works from PA network

### Authentication
- ✅ **Entra ID SSO**: Same authentication flow (no changes)
- ✅ **Private endpoint**: Authentication requests stay within VNet
- ✅ **Token validation**: Handled by API Function (unchanged)

### Access Control
- ✅ **Network-level**: Only PA network can reach Private Endpoint
- ✅ **Application-level**: Entra ID authentication required
- ✅ **RBAC**: Same managed identities and roles (no changes)

---

## Migration Path

### Phase 1: Deploy Frontend Function (Parallel)
1. Create Frontend Function in shared ASE
2. Deploy React SPA to Function
3. Configure Private DNS Zone
4. Test access from PA network via Private Endpoint
5. **Keep Static Web App running** (no disruption)

### Phase 2: User Testing
1. Provide test URL: `https://gcloud-app.pa.internal`
2. Verify authentication works
3. Test all functionality
4. Gather user feedback

### Phase 3: Cutover
1. Update user documentation with new URL
2. Monitor Function metrics
3. Decommission Static Web App (after confirmation period)
4. Remove Front Door (if used)

### Rollback Plan
- Static Web App remains available during transition
- Can switch back instantly if issues arise
- No data migration required (same storage/backend)

---

## Monitoring & Operations

### Function Metrics
- **Execution count**: Track usage during 6-week periods
- **Execution time**: Monitor performance
- **Errors**: Alert on failures
- **Cost**: Track consumption plan charges

### Application Insights
- Same monitoring as current API Function
- Frontend Function logs to same Application Insights
- Unified dashboard for all Functions

### Cost Monitoring
- Azure Cost Management alerts
- Set budget alerts for Function executions
- Track Private Endpoint costs (shared)

---

## FAQ

**Q: Will users need to install anything?**
A: No. Users just need to be on PA network (VPN/ExpressRoute) and use the private URL.

**Q: What if a user is working from home?**
A: They connect to PA VPN first, then access the application normally.

**Q: Can we use a custom domain?**
A: Yes, but it must resolve via Private DNS. You can use `gcloud.paconsulting.com` if you control the DNS and configure it to resolve to Private Endpoint IP from PA network.

**Q: What about mobile users?**
A: Mobile devices need to connect via VPN to PA network, then access the private URL.

**Q: How do we handle SSL certificates?**
A: App Service Environment provides managed certificates for Private Endpoint. Or use Azure Key Vault certificates.

**Q: What if the shared ASE is decommissioned?**
A: Functions can be moved to a new ASE or Premium plan. The architecture is flexible.

---

## Conclusion

This serverless, fully private architecture provides:
- **Zero idle costs** (perfect for 18-24 month usage cycles)
- **Complete network isolation** (no public endpoints)
- **Friendly private URLs** (seamless user experience)
- **Minimal changes** (works with existing design)
- **Significant cost savings** (~£130-170/year)

The solution leverages the shared App Service Environment infrastructure while adding a cost-effective frontend Function that only charges when the application is actively used.

---

**Next Steps**: Review with security team, plan DNS configuration with network team, schedule migration during next usage period.

