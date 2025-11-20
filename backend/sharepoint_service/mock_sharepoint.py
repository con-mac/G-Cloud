"""
Mock SharePoint service for development and testing.
Mimics SharePoint operations using local file system.
"""

import os
import re
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import logging

logger = logging.getLogger(__name__)

# Base path for mock SharePoint structure. Support multiple deployment layouts.
_candidate_paths = [
    Path(__file__).resolve().parent.parent.parent / "mock_sharepoint",
    Path(__file__).resolve().parent.parent / "mock_sharepoint",
    Path(__file__).resolve().parents[3] / "mock_sharepoint" if len(Path(__file__).resolve().parents) > 3 else None,
]
MOCK_BASE_PATH = None
for candidate in _candidate_paths:
    if candidate and candidate.exists():
        MOCK_BASE_PATH = candidate
        break

if MOCK_BASE_PATH is None:
    raise FileNotFoundError(
        "Mock SharePoint base path not found. Checked candidates: "
        + ", ".join(str(p) for p in _candidate_paths if p is not None)
    )


def fuzzy_match(query: str, service_name: str) -> bool:
    """
    Case-insensitive contains matching with variation handling.
    Handles: "Test Title v2", "Agile Test Title", "test title", "TEST TITLE"
    
    Args:
        query: Search query string
        service_name: Service name to match against
        
    Returns:
        True if query matches service_name (fuzzy)
    """
    if not query or not service_name:
        return False
    
    query_lower = query.lower().strip()
    service_lower = service_name.lower().strip()
    
    # Remove version indicators (v2, v3, etc.) for matching
    query_clean = re.sub(r'\s+v\d+\s*$', '', query_lower)
    service_clean = re.sub(r'\s+v\d+\s*$', '', service_lower)
    
    # Contains matching (either direction)
    return query_clean in service_clean or service_clean in query_clean


def read_metadata_file(folder_path: Path) -> Optional[Dict[str, str]]:
    """
    Read metadata .txt file and parse SERVICE, OWNER, SPONSOR, LAST EDITED BY.
    
    Args:
        folder_path: Path to service folder containing metadata file
        
    Returns:
        Dict with 'service', 'owner', 'sponsor', 'last_edited_by' or None if not found
    """
    # Find .txt file starting with "OWNER"
    txt_files = list(folder_path.glob("OWNER*.txt"))
    if not txt_files:
        return None
    
    metadata_file = txt_files[0]
    
    try:
        with open(metadata_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Parse format:
        # 1. SERVICE: [Service Name]
        # 2. OWNER: [First name] [Last name]
        # 3. SPONSOR: [First name] [Last name]
        # 4. LAST EDITED BY: [First name] [Last name] (optional)
        
        service_match = re.search(r'1\.\s*SERVICE:\s*(.+?)(?:\n|$)', content, re.IGNORECASE)
        owner_match = re.search(r'2\.\s*OWNER:\s*(.+?)(?:\n|$)', content, re.IGNORECASE)
        sponsor_match = re.search(r'3\.\s*SPONSOR:\s*(.+?)(?:\n|$)', content, re.IGNORECASE)
        last_edited_match = re.search(r'4\.\s*LAST EDITED BY:\s*(.+?)(?:\n|$)', content, re.IGNORECASE)
        
        metadata = {}
        if service_match:
            metadata['service'] = service_match.group(1).strip()
        if owner_match:
            metadata['owner'] = owner_match.group(1).strip()
        if sponsor_match:
            metadata['sponsor'] = sponsor_match.group(1).strip()
        if last_edited_match:
            metadata['last_edited_by'] = last_edited_match.group(1).strip()
        
        return metadata if metadata else None
        
    except Exception as e:
        logger.error(f"Error reading metadata file {metadata_file}: {e}")
        return None


def search_documents(query: str, doc_type: Optional[str] = None, gcloud_version: str = "14", search_all_versions: bool = False) -> List[Dict]:
    """
    Search documents in mock SharePoint structure.
    Searches both LOT 2 and LOT 3 folders.
    Optionally searches all GCloud versions (14 and 15).
    
    Args:
        query: Search query (fuzzy matching)
        doc_type: Optional document type filter ("SERVICE DESC" or "Pricing Doc")
        gcloud_version: GCloud version ("14" or "15") - used if search_all_versions is False
        search_all_versions: If True, search both GCloud 14 and 15
        
    Returns:
        List of matching documents with metadata:
        [{
            "service_name": str,
            "owner": str,
            "sponsor": str,
            "folder_path": str,
            "doc_type": str,
            "lot": str,
            "gcloud_version": str
        }, ...]
    """
    if not query:
        return []
    
    results = []
    
    # Determine which versions to search
    versions_to_search = ["14", "15"] if search_all_versions else [gcloud_version]
    
    for version in versions_to_search:
        base_path = MOCK_BASE_PATH / f"GCloud {version}" / "PA Services"
        
        # Search both LOT 2 and LOT 3
        for lot in ["2", "3"]:
            lot_folder = base_path / f"Cloud Support Services LOT {lot}"
            
            if not lot_folder.exists():
                continue
            
            # Iterate through service folders
            for service_folder in lot_folder.iterdir():
                if not service_folder.is_dir():
                    continue
                
                service_name = service_folder.name
                
                # Read metadata
                metadata = read_metadata_file(service_folder)
                if not metadata:
                    continue
                
                # Fuzzy match against service name
                if not fuzzy_match(query, service_name):
                    continue
                
                # Check for document types (for mock, assume both exist if metadata exists)
                # In real SharePoint, we'd check if documents exist
                doc_types = []
                
                # Check if documents exist, otherwise assume both types are available
                service_desc_path = service_folder / f"PA GC{version} SERVICE DESC {service_folder.name}.docx"
                pricing_doc_path = service_folder / f"PA GC{version} Pricing Doc {service_folder.name}.docx"
                
                # Also check for draft files
                service_desc_draft_path = service_folder / f"PA GC{version} SERVICE DESC {service_folder.name}_draft.docx"
                pricing_doc_draft_path = service_folder / f"PA GC{version} Pricing Doc {service_folder.name}_draft.docx"
                
                if service_desc_path.exists() or service_desc_draft_path.exists() or not doc_type or doc_type == "SERVICE DESC":
                    doc_types.append("SERVICE DESC")
                if pricing_doc_path.exists() or pricing_doc_draft_path.exists() or not doc_type or doc_type == "Pricing Doc":
                    doc_types.append("Pricing Doc")
                
                # Filter by doc_type if specified
                if doc_type:
                    if doc_type not in doc_types:
                        # For mock, still return if metadata exists
                        doc_types = [doc_type]
                
                # Add results for each document type
                for dt in doc_types:
                    results.append({
                        "service_name": metadata.get('service', service_name),
                        "owner": metadata.get('owner', ''),
                        "sponsor": metadata.get('sponsor', ''),
                        "folder_path": str(service_folder),
                        "doc_type": dt,
                        "lot": lot,
                        "gcloud_version": version
                    })
    
    return results


def get_document_path(service_name: str, doc_type: str, lot: str, gcloud_version: str = "14") -> Optional[Path]:
    """
    Get path to document file.
    Checks Azure Blob Storage if in Azure environment, otherwise checks local filesystem.
    
    Args:
        service_name: Service name
        doc_type: Document type ("SERVICE DESC" or "Pricing Doc")
        lot: LOT number ("2" or "3")
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        Path to document file or None if not found
        In Azure, returns a special marker object that read_document_content can handle
    """
    import os
    
    # Check if we're in Azure (has Azure Storage connection string)
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    if use_azure:
        # In Azure: check Azure Blob Storage
        try:
            from app.services.azure_blob_service import AzureBlobService
            azure_blob_service = AzureBlobService()
            
            # Normalize service name for folder matching
            import re
            service_folder_normalized = re.sub(r"[^\w\s\-]", "", service_name).strip()
            service_folder_normalized = re.sub(r"\s+", "_", service_folder_normalized)
            
            # Search for matching service folders in Azure Blob Storage
            base_prefix = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/"
            blob_list = azure_blob_service.list_blobs(prefix=base_prefix)
            
            # Find service folder using fuzzy match
            service_folder_name = None
            for blob_name in blob_list:
                # Extract folder name from blob path
                # Format: GCloud {version}/PA Services/Cloud Support Services LOT {lot}/{folder}/{filename}
                parts = blob_name.split('/')
                if len(parts) >= 4:
                    folder_name = parts[3]
                    if fuzzy_match(service_name, folder_name):
                        service_folder_name = folder_name
                        break
            
            if not service_folder_name:
                return None
            
            # Determine filename - try regular file first, then draft file
            if doc_type == "SERVICE DESC":
                filename = f"PA GC{gcloud_version} SERVICE DESC {service_name}.docx"
                draft_filename = f"PA GC{gcloud_version} SERVICE DESC {service_name}_draft.docx"
            elif doc_type == "Pricing Doc":
                filename = f"PA GC{gcloud_version} Pricing Doc {service_name}.docx"
                draft_filename = f"PA GC{gcloud_version} Pricing Doc {service_name}_draft.docx"
            else:
                return None
            
            # Try regular file first
            blob_key = f"{base_prefix}{service_folder_name}/{filename}"
            if azure_blob_service.blob_exists(blob_key):
                # Return a special marker that read_document_content can handle
                # We'll use a tuple (blob_key, None) to indicate Azure Blob Storage
                return (blob_key, None)
            
            # If regular file doesn't exist, try draft file
            draft_blob_key = f"{base_prefix}{service_folder_name}/{draft_filename}"
            if azure_blob_service.blob_exists(draft_blob_key):
                return (draft_blob_key, None)
            
            return None
        except Exception as e:
            logger.error(f"Error checking Azure Blob Storage: {e}")
            # Fall through to local filesystem check
    
    # Local filesystem check (original logic)
    base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services"
    lot_folder = base_path / f"Cloud Support Services LOT {lot}"
    
    # Find service folder (fuzzy match)
    service_folder = None
    for folder in lot_folder.iterdir():
        if folder.is_dir() and fuzzy_match(service_name, folder.name):
            service_folder = folder
            break
    
    if not service_folder:
        return None
    
    # Determine filename - try regular file first, then draft file
    if doc_type == "SERVICE DESC":
        filename = f"PA GC{gcloud_version} SERVICE DESC {service_folder.name}.docx"
        draft_filename = f"PA GC{gcloud_version} SERVICE DESC {service_folder.name}_draft.docx"
    elif doc_type == "Pricing Doc":
        filename = f"PA GC{gcloud_version} Pricing Doc {service_folder.name}.docx"
        draft_filename = f"PA GC{gcloud_version} Pricing Doc {service_folder.name}_draft.docx"
    else:
        return None
    
    # Try regular file first
    doc_path = service_folder / filename
    if doc_path.exists():
        return doc_path
    
    # If regular file doesn't exist, try draft file
    draft_path = service_folder / draft_filename
    if draft_path.exists():
        return draft_path
    
    return None


def create_folder(service_name: str, lot: str, gcloud_version: str = "15") -> Tuple[bool, str]:
    """
    Create folder structure for new proposal.
    
    Args:
        service_name: Service name (folder name)
        lot: LOT number ("2" or "3")
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        Tuple of (success: bool, folder_path: str)
    """
    base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services"
    lot_folder = base_path / f"Cloud Support Services LOT {lot}"
    
    # Create LOT folder if it doesn't exist
    lot_folder.mkdir(parents=True, exist_ok=True)
    
    # Create service folder
    service_folder = lot_folder / service_name
    service_folder.mkdir(parents=True, exist_ok=True)
    
    return True, str(service_folder)


def create_metadata_file(folder_path: str, service: str, owner: str, sponsor: str, last_edited_by: Optional[str] = None) -> bool:
    """
    Create metadata .txt file with exact format.
    
    Args:
        folder_path: Path to service folder
        service: Service name
        owner: Owner name (First name Last name)
        sponsor: Sponsor name (First name Last name)
        last_edited_by: Last edited by name (First name Last name) - optional
        
    Returns:
        True if successful, False otherwise
    """
    try:
        folder = Path(folder_path)
        folder.mkdir(parents=True, exist_ok=True)
        
        # Format: OWNER [First name] [Last name].txt
        owner_clean = owner.strip()
        filename = f"OWNER {owner_clean}.txt"
        metadata_path = folder / filename
        
        # Create file with exact format
        content = f"""1. SERVICE: {service}
2. OWNER: {owner}
3. SPONSOR: {sponsor}
"""
        
        # Add last edited by if provided
        if last_edited_by:
            content += f"4. LAST EDITED BY: {last_edited_by}\n"
        
        with open(metadata_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return True
        
    except Exception as e:
        logger.error(f"Error creating metadata file: {e}")
        return False


def list_all_folders(gcloud_version: str = "14") -> List[Dict]:
    """
    List all service folders in mock SharePoint.
    
    Args:
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        List of folders with metadata
    """
    results = []
    base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services"
    
    for lot in ["2", "3"]:
        lot_folder = base_path / f"Cloud Support Services LOT {lot}"
        
        if not lot_folder.exists():
            continue
        
        for service_folder in lot_folder.iterdir():
            if not service_folder.is_dir():
                continue
            
            metadata = read_metadata_file(service_folder)
            if metadata:
                results.append({
                    "service_name": metadata.get('service', service_folder.name),
                    "owner": metadata.get('owner', ''),
                    "sponsor": metadata.get('sponsor', ''),
                    "folder_path": str(service_folder),
                    "lot": lot,
                    "gcloud_version": gcloud_version
                })
    
    return results

