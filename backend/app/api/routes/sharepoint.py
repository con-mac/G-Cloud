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
            
            if not all([tenant_id, client_id, client_secret]):
                return SharePointTestResponse(
                    connected=False,
                    site_id=site_id,
                    site_url=site_url,
                    message="SharePoint credentials not configured",
                    error="AZURE_AD_TENANT_ID, AZURE_AD_CLIENT_ID, or AZURE_AD_CLIENT_SECRET not set"
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
