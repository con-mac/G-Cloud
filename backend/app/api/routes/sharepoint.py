"""SharePoint API routes for testing connectivity"""

from fastapi import APIRouter, HTTPException, Header
from typing import Optional
from pydantic import BaseModel
import os
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


class SharePointTestResponse(BaseModel):
    """SharePoint connectivity test response"""
    connected: bool
    site_id: str
    site_url: str
    message: str
    error: Optional[str] = None


@router.get("/test", response_model=SharePointTestResponse, tags=["SharePoint"])
async def test_sharepoint_connectivity(
    x_user_email: Optional[str] = Header(None, alias="X-User-Email")
):
    """
    Test SharePoint connectivity using App Registration credentials.
    
    This endpoint tests if the backend can connect to SharePoint using:
    - App Registration client credentials (client ID + secret from Key Vault)
    - SharePoint Site ID from configuration
    
    Returns:
        SharePointTestResponse with connection status
    """
    try:
        site_id = os.getenv("SHAREPOINT_SITE_ID", "")
        site_url = os.getenv("SHAREPOINT_SITE_URL", "")
        
        if not site_id or not site_url:
            return SharePointTestResponse(
                connected=False,
                site_id=site_id or "Not configured",
                site_url=site_url or "Not configured",
                message="SharePoint not configured",
                error="SHAREPOINT_SITE_ID or SHAREPOINT_SITE_URL not set"
            )
        
        # Try to get access token using client credentials
        try:
            from azure.identity import ClientSecretCredential
            from msal import ConfidentialClientApplication
            
            tenant_id = os.getenv("AZURE_AD_TENANT_ID", "")
            client_id = os.getenv("AZURE_AD_CLIENT_ID", "")
            client_secret = os.getenv("AZURE_AD_CLIENT_SECRET", "")
            
            # If values are Key Vault references, try to resolve them
            def _get_secret_from_keyvault(secret_name: str) -> Optional[str]:
                try:
                    from azure.keyvault.secrets import SecretClient
                    from azure.identity import DefaultAzureCredential
                    
                    key_vault_url = os.getenv("AZURE_KEY_VAULT_URL", "")
                    if not key_vault_url:
                        # Try to get from Key Vault name
                        kv_name = os.getenv("KEY_VAULT_NAME", "")
                        if kv_name:
                            key_vault_url = f"https://{kv_name}.vault.azure.net"
                    
                    if not key_vault_url:
                        return None
                    
                    credential = DefaultAzureCredential()
                    client = SecretClient(vault_url=key_vault_url, credential=credential)
                    secret = client.get_secret(secret_name)
                    return secret.value
                except Exception as e:
                    logger.debug(f"Could not read secret from Key Vault: {e}")
                    return None
            
            if tenant_id and tenant_id.startswith("@Microsoft.KeyVault"):
                logger.info("Resolving Tenant ID from Key Vault...")
                tenant_id = _get_secret_from_keyvault("AzureADTenantId") or tenant_id
            
            if client_id and client_id.startswith("@Microsoft.KeyVault"):
                logger.info("Resolving Client ID from Key Vault...")
                client_id = _get_secret_from_keyvault("AzureADClientId") or client_id
            
            if client_secret and client_secret.startswith("@Microsoft.KeyVault"):
                logger.info("Resolving Client Secret from Key Vault...")
                client_secret = _get_secret_from_keyvault("AzureADClientSecret") or client_secret
            
            if not all([tenant_id, client_id, client_secret]):
                return SharePointTestResponse(
                    connected=False,
                    site_id=site_id,
                    site_url=site_url,
                    message="SharePoint credentials not configured",
                    error=f"AZURE_AD_TENANT_ID: {'Set' if tenant_id else 'Missing'}, AZURE_AD_CLIENT_ID: {'Set' if client_id else 'Missing'}, AZURE_AD_CLIENT_SECRET: {'Set' if client_secret else 'Missing'}"
                )
            
            # Get access token using client credentials flow
            app = ConfidentialClientApplication(
                client_id=client_id,
                client_credential=client_secret,
                authority=f"https://login.microsoftonline.com/{tenant_id}"
            )
            
            result = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
            
            if "access_token" not in result:
                error_msg = result.get("error_description", "Failed to acquire token")
                return SharePointTestResponse(
                    connected=False,
                    site_id=site_id,
                    site_url=site_url,
                    message="Failed to authenticate with Azure AD",
                    error=error_msg
                )
            
            access_token = result["access_token"]
            
            # Test Graph API call to SharePoint site
            import requests
            graph_url = f"https://graph.microsoft.com/v1.0/sites/{site_id}"
            
            response = requests.get(
                graph_url,
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json"
                },
                timeout=10
            )
            
            if response.status_code == 200:
                site_data = response.json()
                return SharePointTestResponse(
                    connected=True,
                    site_id=site_id,
                    site_url=site_url,
                    message=f"Successfully connected to SharePoint site: {site_data.get('displayName', 'Unknown')}",
                    error=None
                )
            else:
                return SharePointTestResponse(
                    connected=False,
                    site_id=site_id,
                    site_url=site_url,
                    message="Failed to access SharePoint site",
                    error=f"Graph API returned status {response.status_code}: {response.text}"
                )
                
        except ImportError as e:
            return SharePointTestResponse(
                connected=False,
                site_id=site_id,
                site_url=site_url,
                message="SharePoint libraries not available",
                error=f"Import error: {str(e)}"
            )
        except Exception as e:
            logger.error(f"SharePoint connectivity test error: {e}", exc_info=True)
            return SharePointTestResponse(
                connected=False,
                site_id=site_id,
                site_url=site_url,
                message="Error testing SharePoint connectivity",
                error=str(e)
            )
            
    except Exception as e:
        logger.error(f"Unexpected error in SharePoint test: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")
