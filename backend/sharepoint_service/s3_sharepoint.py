"""
S3 SharePoint service for AWS deployment.
Mirrors the mock_sharepoint interface using S3 buckets.
"""

import os
import re
from typing import List, Dict, Optional, Tuple
import logging
import boto3
from botocore.exceptions import ClientError
from io import BytesIO

logger = logging.getLogger(__name__)

# S3 client (will be initialized when needed)
_s3_client = None
_sharepoint_bucket_name = None


def get_s3_client():
    """Get or create S3 client"""
    global _s3_client
    if _s3_client is None:
        _s3_client = boto3.client('s3')
    return _s3_client


def get_sharepoint_bucket():
    """Get SharePoint bucket name from environment"""
    global _sharepoint_bucket_name
    if _sharepoint_bucket_name is None:
        _sharepoint_bucket_name = os.environ.get('SHAREPOINT_BUCKET_NAME', '')
    return _sharepoint_bucket_name


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


def read_metadata_file(folder_path: str) -> Optional[Dict[str, str]]:
    """
    Read metadata .txt file from S3 and parse SERVICE, OWNER, SPONSOR, LAST EDITED BY.
    
    Args:
        folder_path: S3 prefix (folder path) containing metadata file
        
    Returns:
        Dict with 'service', 'owner', 'sponsor', 'last_edited_by' or None if not found
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return None
    
    s3 = get_s3_client()
    
    # List objects in the folder (prefix)
    try:
        # Find .txt file starting with "OWNER"
        prefix = folder_path.rstrip('/') + '/'
        response = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        
        if 'Contents' not in response:
            return None
        
        # Find OWNER*.txt file
        metadata_key = None
        for obj in response['Contents']:
            key = obj['Key']
            if key.endswith('.txt') and 'OWNER' in key:
                metadata_key = key
                break
        
        if not metadata_key:
            return None
        
        # Read metadata file
        obj_response = s3.get_object(Bucket=bucket_name, Key=metadata_key)
        content = obj_response['Body'].read().decode('utf-8')
        
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
        
    except ClientError as e:
        logger.error(f"Error reading metadata file from S3: {e}")
        return None
    except Exception as e:
        logger.error(f"Error parsing metadata file: {e}")
        return None


def search_documents(query: str, doc_type: Optional[str] = None, gcloud_version: str = "14", search_all_versions: bool = False) -> List[Dict]:
    """
    Search documents in S3 SharePoint structure.
    Searches both LOT 2 and LOT 3 folders.
    Optionally searches all GCloud versions (14 and 15).
    
    Args:
        query: Search query (fuzzy matching)
        doc_type: Optional document type filter ("SERVICE DESC" or "Pricing Doc")
        gcloud_version: GCloud version ("14" or "15") - used if search_all_versions is False
        search_all_versions: If True, search both GCloud 14 and 15
        
    Returns:
        List of matching documents with metadata
    """
    if not query:
        return []
    
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return []
    
    s3 = get_s3_client()
    results = []
    
    # Determine which versions to search
    versions_to_search = ["14", "15"] if search_all_versions else [gcloud_version]
    
    for version in versions_to_search:
        base_prefix = f"GCloud {version}/PA Services/"
        
        # Search both LOT 2 and LOT 3
        for lot in ["2", "3"]:
            lot_prefix = base_prefix + f"Cloud Support Services LOT {lot}/"
            
            try:
                # List all service folders
                paginator = s3.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=bucket_name, Prefix=lot_prefix, Delimiter='/')
                
                for page in pages:
                    # Get common prefixes (folders)
                    if 'CommonPrefixes' not in page:
                        continue
                    
                    for prefix_info in page['CommonPrefixes']:
                        service_prefix = prefix_info['Prefix']
                        service_folder_name = service_prefix.rstrip('/').split('/')[-1]
                        
                        # Read metadata
                        metadata = read_metadata_file(service_prefix)
                        if not metadata:
                            continue
                        
                        # Fuzzy match against service name
                        if not fuzzy_match(query, service_folder_name):
                            continue
                        
                        # Check for document types
                        doc_types = []
                        
                        # Check if documents exist
                        service_desc_key = f"{service_prefix}PA GC{version} SERVICE DESC {service_folder_name}.docx"
                        pricing_doc_key = f"{service_prefix}PA GC{version} Pricing Doc {service_folder_name}.docx"
                        service_desc_draft_key = f"{service_prefix}PA GC{version} SERVICE DESC {service_folder_name}_draft.docx"
                        pricing_doc_draft_key = f"{service_prefix}PA GC{version} Pricing Doc {service_folder_name}_draft.docx"
                        
                        # Check if files exist
                        try:
                            s3.head_object(Bucket=bucket_name, Key=service_desc_key)
                            doc_types.append("SERVICE DESC")
                        except ClientError:
                            try:
                                s3.head_object(Bucket=bucket_name, Key=service_desc_draft_key)
                                doc_types.append("SERVICE DESC")
                            except ClientError:
                                if not doc_type or doc_type == "SERVICE DESC":
                                    doc_types.append("SERVICE DESC")
                        
                        try:
                            s3.head_object(Bucket=bucket_name, Key=pricing_doc_key)
                            doc_types.append("Pricing Doc")
                        except ClientError:
                            try:
                                s3.head_object(Bucket=bucket_name, Key=pricing_doc_draft_key)
                                doc_types.append("Pricing Doc")
                            except ClientError:
                                if not doc_type or doc_type == "Pricing Doc":
                                    doc_types.append("Pricing Doc")
                        
                        # Filter by doc_type if specified
                        if doc_type:
                            if doc_type not in doc_types:
                                doc_types = [doc_type]
                        
                        # Add results for each document type
                        for dt in doc_types:
                            results.append({
                                "service_name": metadata.get('service', service_folder_name),
                                "owner": metadata.get('owner', ''),
                                "sponsor": metadata.get('sponsor', ''),
                                "folder_path": service_prefix,
                                "doc_type": dt,
                                "lot": lot,
                                "gcloud_version": version
                            })
            except ClientError as e:
                logger.error(f"Error searching S3: {e}")
                continue
    
    return results


def get_document_path(service_name: str, doc_type: str, lot: str, gcloud_version: str = "14") -> Optional[str]:
    """
    Get S3 key (path) to document file.
    
    Args:
        service_name: Service name
        doc_type: Document type ("SERVICE DESC" or "Pricing Doc")
        lot: LOT number ("2" or "3")
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        S3 key (path) to document file or None if not found
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return None
    
    s3 = get_s3_client()
    base_prefix = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/"
    
    try:
        # List all service folders
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=base_prefix, Delimiter='/')
        
        service_folder_name = None
        for page in pages:
            if 'CommonPrefixes' not in page:
                continue
            
            for prefix_info in page['CommonPrefixes']:
                folder_name = prefix_info['Prefix'].rstrip('/').split('/')[-1]
                if fuzzy_match(service_name, folder_name):
                    service_folder_name = folder_name
                    service_prefix = prefix_info['Prefix']
                    break
            
            if service_folder_name:
                break
        
        if not service_folder_name:
            return None
        
        # Determine filename - try regular file first, then draft file
        if doc_type == "SERVICE DESC":
            filename = f"PA GC{gcloud_version} SERVICE DESC {service_folder_name}.docx"
            draft_filename = f"PA GC{gcloud_version} SERVICE DESC {service_folder_name}_draft.docx"
        elif doc_type == "Pricing Doc":
            filename = f"PA GC{gcloud_version} Pricing Doc {service_folder_name}.docx"
            draft_filename = f"PA GC{gcloud_version} Pricing Doc {service_folder_name}_draft.docx"
        else:
            return None
        
        # Try regular file first
        doc_key = f"{service_prefix}{filename}"
        try:
            s3.head_object(Bucket=bucket_name, Key=doc_key)
            return doc_key
        except ClientError:
            # If regular file doesn't exist, try draft file
            draft_key = f"{service_prefix}{draft_filename}"
            try:
                s3.head_object(Bucket=bucket_name, Key=draft_key)
                return draft_key
            except ClientError:
                return None
    
    except ClientError as e:
        logger.error(f"Error getting document path from S3: {e}")
        return None


def create_folder(service_name: str, lot: str, gcloud_version: str = "15") -> Tuple[bool, str]:
    """
    Create folder structure in S3 for new proposal.
    In S3, folders are just prefixes, so we just return the prefix path.
    
    Args:
        service_name: Service name (folder name)
        lot: LOT number ("2" or "3")
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        Tuple of (success: bool, folder_path: str)
    """
    folder_path = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/"
    # In S3, folders are implicit (just prefixes), so we don't need to create them
    # They'll be created when we upload files
    return True, folder_path


def create_metadata_file(folder_path: str, service: str, owner: str, sponsor: str, last_edited_by: Optional[str] = None) -> bool:
    """
    Create metadata .txt file in S3 with exact format.
    
    Args:
        folder_path: S3 prefix (folder path)
        service: Service name
        owner: Owner name (First name Last name)
        sponsor: Sponsor name (First name Last name)
        last_edited_by: Last edited by name (First name Last name) - optional
        
    Returns:
        True if successful, False otherwise
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return False
    
    s3 = get_s3_client()
    
    try:
        # Format: OWNER [First name] [Last name].txt
        owner_clean = owner.strip()
        filename = f"OWNER {owner_clean}.txt"
        metadata_key = f"{folder_path.rstrip('/')}/{filename}"
        
        # Create file content with exact format
        content = f"""1. SERVICE: {service}
2. OWNER: {owner}
3. SPONSOR: {sponsor}
"""
        
        # Add last edited by if provided
        if last_edited_by:
            content += f"4. LAST EDITED BY: {last_edited_by}\n"
        
        # Upload to S3
        s3.put_object(
            Bucket=bucket_name,
            Key=metadata_key,
            Body=content.encode('utf-8'),
            ContentType='text/plain'
        )
        
        return True
        
    except ClientError as e:
        logger.error(f"Error creating metadata file in S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Error creating metadata file: {e}")
        return False


def list_all_folders(gcloud_version: str = "14") -> List[Dict]:
    """
    List all service folders in S3 SharePoint.
    
    Args:
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        List of folders with metadata
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return []
    
    s3 = get_s3_client()
    results = []
    base_prefix = f"GCloud {gcloud_version}/PA Services/"
    
    for lot in ["2", "3"]:
        lot_prefix = base_prefix + f"Cloud Support Services LOT {lot}/"
        
        try:
            paginator = s3.get_paginator('list_objects_v2')
            pages = paginator.paginate(Bucket=bucket_name, Prefix=lot_prefix, Delimiter='/')
            
            for page in pages:
                if 'CommonPrefixes' not in page:
                    continue
                
                for prefix_info in page['CommonPrefixes']:
                    service_prefix = prefix_info['Prefix']
                    
                    metadata = read_metadata_file(service_prefix)
                    if metadata:
                        results.append({
                            "service_name": metadata.get('service', service_prefix.rstrip('/').split('/')[-1]),
                            "owner": metadata.get('owner', ''),
                            "sponsor": metadata.get('sponsor', ''),
                            "folder_path": service_prefix,
                            "lot": lot,
                            "gcloud_version": gcloud_version
                        })
        except ClientError as e:
            logger.error(f"Error listing folders from S3: {e}")
            continue
    
    return results


# S3-specific helper functions
def upload_file_to_s3(local_path: str, s3_key: str) -> bool:
    """
    Upload a local file to S3.
    
    Args:
        local_path: Local file path
        s3_key: S3 key (path) to upload to
        
    Returns:
        True if successful, False otherwise
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return False
    
    s3 = get_s3_client()
    
    try:
        with open(local_path, 'rb') as f:
            s3.upload_fileobj(f, bucket_name, s3_key)
        return True
    except ClientError as e:
        logger.error(f"Error uploading file to S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Error uploading file: {e}")
        return False


def download_file_from_s3(s3_key: str, local_path: str) -> bool:
    """
    Download a file from S3 to local path.
    
    Args:
        s3_key: S3 key (path) to download from
        local_path: Local file path to save to
        
    Returns:
        True if successful, False otherwise
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return False
    
    s3 = get_s3_client()
    
    try:
        s3.download_file(bucket_name, s3_key, local_path)
        return True
    except ClientError as e:
        logger.error(f"Error downloading file from S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Error downloading file: {e}")
        return False


def get_file_from_s3(s3_key: str) -> Optional[BytesIO]:
    """
    Get file content from S3 as BytesIO.
    
    Args:
        s3_key: S3 key (path) to get
        
    Returns:
        BytesIO object with file content or None if not found
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return None
    
    s3 = get_s3_client()
    
    try:
        response = s3.get_object(Bucket=bucket_name, Key=s3_key)
        return BytesIO(response['Body'].read())
    except ClientError as e:
        logger.error(f"Error getting file from S3: {e}")
        return None
    except Exception as e:
        logger.error(f"Error getting file: {e}")
        return None


def delete_file_from_s3(s3_key: str) -> bool:
    """
    Delete a file from S3.
    
    Args:
        s3_key: S3 key (path) to delete
        
    Returns:
        True if successful, False otherwise
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return False
    
    s3 = get_s3_client()
    
    try:
        s3.delete_object(Bucket=bucket_name, Key=s3_key)
        return True
    except ClientError as e:
        logger.error(f"Error deleting file from S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Error deleting file: {e}")
        return False


def list_files_in_folder(folder_path: str) -> List[str]:
    """
    List all files in an S3 folder (prefix).
    
    Args:
        folder_path: S3 prefix (folder path)
        
    Returns:
        List of S3 keys (file paths)
    """
    bucket_name = get_sharepoint_bucket()
    if not bucket_name:
        logger.error("SHAREPOINT_BUCKET_NAME not set")
        return []
    
    s3 = get_s3_client()
    files = []
    
    try:
        paginator = s3.get_paginator('list_objects_v2')
        pages = paginator.paginate(Bucket=bucket_name, Prefix=folder_path)
        
        for page in pages:
            if 'Contents' not in page:
                continue
            
            for obj in page['Contents']:
                # Skip if it's a "folder" (ends with /)
                if not obj['Key'].endswith('/'):
                    files.append(obj['Key'])
        
        return files
    except ClientError as e:
        logger.error(f"Error listing files from S3: {e}")
        return []
    except Exception as e:
        logger.error(f"Error listing files: {e}")
        return []

