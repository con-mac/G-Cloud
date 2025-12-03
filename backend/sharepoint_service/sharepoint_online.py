"""
SharePoint Online integration using Microsoft Graph API
"""

import os
import logging
from typing import List, Dict, Optional, Tuple
from pathlib import Path
import json
import requests
from msal import ConfidentialClientApplication

logger = logging.getLogger(__name__)

# Configuration from environment
SHAREPOINT_SITE_URL = os.environ.get("SHAREPOINT_SITE_URL", "")
SHAREPOINT_SITE_ID = os.environ.get("SHAREPOINT_SITE_ID", "")
SHAREPOINT_DRIVE_ID = os.environ.get("SHAREPOINT_DRIVE_ID", "")

# No local base path for SharePoint Online
MOCK_BASE_PATH = None

# Graph API endpoint
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"
GRAPH_API_SCOPE = "https://graph.microsoft.com/.default"

# Cache for access token
_access_token = None
_token_expiry = None


def _get_secret_from_keyvault(secret_name: str, key_vault_url: str = None) -> Optional[str]:
    """
    Get secret from Key Vault if environment variable is a Key Vault reference
    """
    try:
        from azure.keyvault.secrets import SecretClient
        from azure.identity import DefaultAzureCredential
        
        if not key_vault_url:
            # Try to get Key Vault URL from environment
            key_vault_url = os.environ.get("AZURE_KEY_VAULT_URL", "")
            if not key_vault_url:
                # Try to construct from Key Vault name
                kv_name = os.environ.get("KEY_VAULT_NAME", "")
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


def get_access_token() -> Optional[str]:
    """
    Get or refresh access token for Microsoft Graph API
    Uses client credentials flow (app-only authentication)
    """
    global _access_token, _token_expiry
    
    # Check if we have a valid token
    if _access_token and _token_expiry:
        import time
        if time.time() < _token_expiry:
            return _access_token
    
    try:
        tenant_id = os.environ.get("AZURE_AD_TENANT_ID", "")
        client_id = os.environ.get("AZURE_AD_CLIENT_ID", "")
        client_secret = os.environ.get("AZURE_AD_CLIENT_SECRET", "")
        
        # If values are missing or Key Vault references, try to read from Key Vault
        if not tenant_id or tenant_id.startswith("@Microsoft.KeyVault"):
            logger.info("Tenant ID missing or is Key Vault reference, reading from Key Vault...")
            tenant_id = _get_secret_from_keyvault("AzureADTenantId") or tenant_id
        
        if not client_id or client_id.startswith("@Microsoft.KeyVault"):
            logger.info("Client ID missing or is Key Vault reference, reading from Key Vault...")
            client_id = _get_secret_from_keyvault("AzureADClientId") or client_id
        
        if not client_secret or client_secret.startswith("@Microsoft.KeyVault"):
            logger.info("Client Secret missing or is Key Vault reference, reading from Key Vault...")
            client_secret = _get_secret_from_keyvault("AzureADClientSecret") or client_secret
        
        if not all([tenant_id, client_id, client_secret]):
            logger.error("Missing Azure AD credentials for SharePoint authentication")
            logger.error(f"Tenant ID: {'Set' if tenant_id else 'Missing'}")
            logger.error(f"Client ID: {'Set' if client_id else 'Missing'}")
            logger.error(f"Client Secret: {'Set' if client_secret else 'Missing'}")
            return None
        
        # Get access token using client credentials flow
        app = ConfidentialClientApplication(
            client_id=client_id,
            client_credential=client_secret,
            authority=f"https://login.microsoftonline.com/{tenant_id}"
        )
        
        result = app.acquire_token_for_client(scopes=[GRAPH_API_SCOPE])
        
        if "access_token" not in result:
            error_msg = result.get("error_description", "Failed to acquire token")
            logger.error(f"Failed to acquire access token: {error_msg}")
            return None
        
        _access_token = result["access_token"]
        # Token expires in ~1 hour, refresh 5 minutes early
        expires_in = result.get("expires_in", 3600)
        import time
        _token_expiry = time.time() + expires_in - 300
        
        return _access_token
        
    except Exception as e:
        logger.error(f"Error getting access token: {e}", exc_info=True)
        return None


def _make_graph_request(method: str, endpoint: str, **kwargs) -> Optional[requests.Response]:
    """
    Make a request to Microsoft Graph API
    """
    token = get_access_token()
    if not token:
        return None
    
    url = f"{GRAPH_API_ENDPOINT}/{endpoint.lstrip('/')}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    if "headers" in kwargs:
        headers.update(kwargs.pop("headers"))
    
    try:
        response = requests.request(method, url, headers=headers, timeout=30, **kwargs)
        return response
    except Exception as e:
        logger.error(f"Graph API request failed: {e}", exc_info=True)
        return None


def fuzzy_match(query: str, service_name: str) -> bool:
    """
    Case-insensitive contains matching with variation handling.
    Reuses logic from mock_sharepoint for consistency.
    """
    try:
        from sharepoint_service.mock_sharepoint import fuzzy_match as base_fuzzy_match
        return base_fuzzy_match(query, service_name)
    except ImportError:
        # Fallback implementation
        if not query or not service_name:
            return False
        query_lower = query.lower().strip()
        service_lower = service_name.lower().strip()
        return query_lower in service_lower or service_lower in query_lower


def read_metadata_file(folder_path: str) -> Optional[Dict[str, str]]:
    """
    Read metadata.json file from SharePoint folder
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return None
    
    try:
        # Construct path to metadata.json in the folder
        metadata_path = f"{folder_path.rstrip('/')}/metadata.json"
        
        # Get file content using Graph API
        # Format: /sites/{site-id}/drive/root:/{path}:/content
        endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{metadata_path}:/content"
        response = _make_graph_request("GET", endpoint)
        
        if response and response.status_code == 200:
            try:
                metadata = json.loads(response.text)
                return metadata
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse metadata.json: {e}")
                return None
        elif response and response.status_code == 404:
            logger.debug(f"Metadata file not found at {metadata_path}")
            return None
        else:
            logger.warning(f"Failed to read metadata file: {response.status_code if response else 'No response'}")
            return None
            
    except Exception as e:
        logger.error(f"Error reading metadata file: {e}", exc_info=True)
        return None


def search_documents(
    service_name: str,
    doc_type: str,
    lot: str,
    gcloud_version: str
) -> List[Dict[str, any]]:
    """
    Search for documents in SharePoint using Graph API search
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return []
    
    try:
        # Search in the site's drive
        # Format: /sites/{site-id}/drive/root/search(q='{query}')
        search_query = f"{service_name} {doc_type}"
        endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root/search(q='{search_query}')"
        response = _make_graph_request("GET", endpoint)
        
        if response and response.status_code == 200:
            data = response.json()
            documents = []
            for item in data.get("value", []):
                if item.get("file"):
                    documents.append({
                        "name": item.get("name", ""),
                        "id": item.get("id", ""),
                        "webUrl": item.get("webUrl", ""),
                        "size": item.get("size", 0),
                        "lastModifiedDateTime": item.get("lastModifiedDateTime", ""),
                    })
            return documents
        else:
            logger.warning(f"Search failed: {response.status_code if response else 'No response'}")
            return []
            
    except Exception as e:
        logger.error(f"Error searching documents: {e}", exc_info=True)
        return []


def get_document_path(
    service_name: str,
    doc_type: str,
    lot: str,
    gcloud_version: str
) -> Tuple[Optional[str], Optional[Path]]:
    """
    Get document path/item ID in SharePoint
    Returns: (item_id, None) tuple for SharePoint (consistent with Azure Blob Storage pattern)
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return (None, None)
    
    try:
        # Construct expected path in SharePoint
        # Format: GCloud {version}/PA Services/{service_name}/{doc_type}
        folder_path = f"GCloud {gcloud_version}/PA Services/{service_name}"
        filename = f"{doc_type}.docx"  # Assuming .docx format
        
        # Try to get the file
        file_path = f"{folder_path}/{filename}"
        endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{file_path}"
        response = _make_graph_request("GET", endpoint)
        
        if response and response.status_code == 200:
            item = response.json()
            item_id = item.get("id", "")
            return (item_id, None) if item_id else (None, None)
        else:
            logger.debug(f"Document not found at {file_path}")
            return (None, None)
            
    except Exception as e:
        logger.error(f"Error getting document path: {e}", exc_info=True)
        return (None, None)


def create_folder(
    folder_path: str,
    gcloud_version: str = "15"
) -> str:
    """
    Create folder structure in SharePoint
    Returns: Folder item ID
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return ""
    
    try:
        # Parse folder path and create parent folders if needed
        parts = folder_path.strip("/").split("/")
        current_path = f"GCloud {gcloud_version}/PA Services"
        
        for part in parts:
            if not part:
                continue
            current_path = f"{current_path}/{part}"
            
            # Check if folder exists
            check_endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{current_path}"
            check_response = _make_graph_request("GET", check_endpoint)
            
            if check_response and check_response.status_code == 200:
                # Folder exists, get its ID
                folder_id = check_response.json().get("id", "")
            else:
                # Create folder
                parent_path = "/".join(current_path.split("/")[:-1])
                parent_endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{parent_path}"
                parent_response = _make_graph_request("GET", parent_endpoint)
                
                if parent_response and parent_response.status_code == 200:
                    parent_id = parent_response.json().get("id", "")
                    create_endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/items/{parent_id}/children"
                    create_data = {
                        "name": part,
                        "folder": {},
                        "@microsoft.graph.conflictBehavior": "rename"
                    }
                    create_response = _make_graph_request("POST", create_endpoint, json=create_data)
                    
                    if create_response and create_response.status_code == 201:
                        folder_id = create_response.json().get("id", "")
                    else:
                        logger.error(f"Failed to create folder {part}: {create_response.status_code if create_response else 'No response'}")
                        return ""
                else:
                    logger.error(f"Failed to get parent folder: {parent_path}")
                    return ""
        
        return folder_id if 'folder_id' in locals() else ""
        
    except Exception as e:
        logger.error(f"Error creating folder: {e}", exc_info=True)
        return ""


def create_metadata_file(
    folder_path: str,
    metadata: Dict[str, str],
    gcloud_version: str = "15"
) -> bool:
    """
    Create metadata.json file in SharePoint folder
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return False
    
    try:
        # Get folder ID
        folder_endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{folder_path}"
        folder_response = _make_graph_request("GET", folder_endpoint)
        
        if not folder_response or folder_response.status_code != 200:
            logger.error(f"Folder not found: {folder_path}")
            return False
        
        folder_id = folder_response.json().get("id", "")
        
        # Upload metadata.json file
        upload_endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/items/{folder_id}:/metadata.json:/content"
        metadata_json = json.dumps(metadata, indent=2)
        upload_response = _make_graph_request("PUT", upload_endpoint, data=metadata_json.encode('utf-8'))
        
        if upload_response and upload_response.status_code in [200, 201]:
            logger.info(f"Metadata file created at {folder_path}/metadata.json")
            return True
        else:
            logger.error(f"Failed to create metadata file: {upload_response.status_code if upload_response else 'No response'}")
            return False
            
    except Exception as e:
        logger.error(f"Error creating metadata file: {e}", exc_info=True)
        return False


def list_all_folders(gcloud_version: str = "15") -> List[Dict[str, any]]:
    """
    List all service folders in SharePoint
    """
    if not SHAREPOINT_SITE_ID:
        logger.error("SHAREPOINT_SITE_ID not configured")
        return []
    
    try:
        # List folders in the PA Services directory
        folder_path = f"GCloud {gcloud_version}/PA Services"
        endpoint = f"sites/{SHAREPOINT_SITE_ID}/drive/root:/{folder_path}:/children"
        response = _make_graph_request("GET", endpoint)
        
        if response and response.status_code == 200:
            data = response.json()
            folders = []
            for item in data.get("value", []):
                if item.get("folder"):
                    folders.append({
                        "name": item.get("name", ""),
                        "id": item.get("id", ""),
                        "webUrl": item.get("webUrl", ""),
                    })
            return folders
        else:
            logger.warning(f"Failed to list folders: {response.status_code if response else 'No response'}")
            return []
            
    except Exception as e:
        logger.error(f"Error listing folders: {e}", exc_info=True)
        return []


def upload_file_to_sharepoint(
    file_path: Path,
    target_path: str,
    gcloud_version: str = "15"
) -> Optional[str]:
    """
    Upload file to SharePoint
    Returns: Item ID if successful
    PLACEHOLDER: Implement with Graph API
    """
    # PLACEHOLDER: Use Graph API to upload file
    # Example: PUT /sites/{site-id}/drive/items/{parent-id}:/{filename}:/content
    logger.warning("upload_file_to_sharepoint: Using placeholder - not implemented")
    return None


def download_file_from_sharepoint(
    item_id: str
) -> Optional[bytes]:
    """
    Download file from SharePoint
    PLACEHOLDER: Implement with Graph API
    """
    # PLACEHOLDER: Use Graph API to download file
    # Example: GET /sites/{site-id}/drive/items/{item-id}/content
    logger.warning("download_file_from_sharepoint: Using placeholder - not implemented")
    return None


def file_exists_in_sharepoint(item_id: str) -> bool:
    """
    Check if file exists in SharePoint
    PLACEHOLDER: Implement with Graph API
    """
    # PLACEHOLDER: Use Graph API to check file existence
    # Example: GET /sites/{site-id}/drive/items/{item-id}
    logger.warning("file_exists_in_sharepoint: Using placeholder - not implemented")
    return False


def get_file_properties(item_id: str) -> Optional[Dict]:
    """
    Get file properties from SharePoint
    PLACEHOLDER: Implement with Graph API
    """
    # PLACEHOLDER: Use Graph API to get file properties
    # Example: GET /sites/{site-id}/drive/items/{item-id}
    logger.warning("get_file_properties: Using placeholder - not implemented")
    return None

