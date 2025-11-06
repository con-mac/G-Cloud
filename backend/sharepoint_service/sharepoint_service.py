"""
SharePoint service abstraction layer.
Switches between local mock_sharepoint and S3 s3_sharepoint based on USE_S3 environment variable.
"""

import os
from typing import List, Dict, Optional, Tuple
from pathlib import Path

# Check if we should use S3
USE_S3 = os.environ.get('USE_S3', 'false').lower() == 'true'

if USE_S3:
    # Import S3 service
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
else:
    # Import local mock service
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

