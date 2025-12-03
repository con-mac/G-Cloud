"""
SharePoint service abstraction layer.
Switches between local mock_sharepoint and S3 s3_sharepoint based on USE_S3 environment variable.
"""

import os
from typing import List, Dict, Optional, Tuple
from pathlib import Path

# Check which SharePoint backend to use
USE_SHAREPOINT = os.environ.get('USE_SHAREPOINT', 'false').lower() == 'true'
USE_S3 = os.environ.get('USE_S3', 'false').lower() == 'true'

# Check if we're in Azure (has storage connection string)
IN_AZURE = bool(os.environ.get('AZURE_STORAGE_CONNECTION_STRING', ''))

# Initialize defaults
MOCK_BASE_PATH = None
fuzzy_match = None
read_metadata_file = None
search_documents = None
get_document_path = None
create_folder = None
create_metadata_file = None
list_all_folders = None
upload_file_to_s3 = None
download_file_from_s3 = None
get_file_from_s3 = None
delete_file_from_s3 = None
list_files_in_folder = None

if USE_SHAREPOINT:
    # Import live SharePoint Online service
    try:
        from sharepoint_service.sharepoint_online import (
            fuzzy_match,
            read_metadata_file,
            search_documents,
            get_document_path,
            create_folder,
            create_metadata_file,
            list_all_folders,
            MOCK_BASE_PATH,
        )
        # For SharePoint Online, get_document_path returns a string (item ID), not a Path
        # S3 helper functions are not available
        upload_file_to_s3 = None
        download_file_from_s3 = None
        get_file_from_s3 = None
        delete_file_from_s3 = None
        list_files_in_folder = None
    except (ImportError, AttributeError) as e:
        import logging
        logging.warning(f"Failed to import SharePoint Online service: {e}")
        # Functions will be None, calling code should handle this
        if not IN_AZURE:
            logging.error(f"SharePoint Online import failed and not in Azure: {e}")
elif USE_S3:
    # Import S3 service
    try:
        from sharepoint_service.s3_sharepoint import (
            fuzzy_match,
            read_metadata_file,
            search_documents,
            get_document_path,
            create_folder,
            create_metadata_file,
            list_all_folders,
            upload_file_to_s3,
            download_file_from_s3,
            get_file_from_s3,
            delete_file_from_s3,
            list_files_in_folder,
        )
        # For S3, get_document_path returns a string (S3 key), not a Path
        # We need to handle this in the calling code
        MOCK_BASE_PATH = None
    except ImportError as e:
        import logging
        logging.warning(f"Failed to import S3 SharePoint service: {e}")
        # Functions will be None, calling code should handle this
else:
    # Import local mock service
    try:
        from sharepoint_service.mock_sharepoint import (
            fuzzy_match,
            read_metadata_file,
            search_documents,
            get_document_path,
            create_folder,
            create_metadata_file,
            list_all_folders,
            MOCK_BASE_PATH,
        )
        # For local, get_document_path returns a Path object
        # S3 helper functions are not available
        upload_file_to_s3 = None
        download_file_from_s3 = None
        get_file_from_s3 = None
        delete_file_from_s3 = None
        list_files_in_folder = None
    except (ImportError, FileNotFoundError) as e:
        import logging
        logging.warning(f"Failed to import mock SharePoint service: {e}")
        # If in Azure, this is OK - we'll use Azure Blob Storage instead
        # Functions will be None, calling code should handle this
        if not IN_AZURE:
            # Only log as error if not in Azure (where we might use Blob Storage)
            logging.error(f"Mock SharePoint import failed and not in Azure: {e}")

# Export all functions
__all__ = [
    'fuzzy_match',
    'read_metadata_file',
    'search_documents',
    'get_document_path',
    'create_folder',
    'create_metadata_file',
    'list_all_folders',
    'MOCK_BASE_PATH',
    'USE_S3',
    'upload_file_to_s3',
    'download_file_from_s3',
    'get_file_from_s3',
    'delete_file_from_s3',
    'list_files_in_folder',
]

