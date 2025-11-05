"""
Word document parser for extracting content from existing documents
"""

from pathlib import Path
from typing import Dict, List, Optional
from docx import Document
import logging

logger = logging.getLogger(__name__)


def parse_service_description_document(doc_path: Path) -> Dict:
    """
    Parse a Service Description Word document and extract content.
    
    Args:
        doc_path: Path to Word document (.docx file)
        
    Returns:
        Dict with extracted content:
        {
            'title': str,
            'description': str,
            'features': List[str],
            'benefits': List[str],
            'service_definition': List[{'subtitle': str, 'content': str}]
        }
    """
    try:
        doc = Document(str(doc_path))
        
        result = {
            'title': '',
            'description': '',
            'features': [],
            'benefits': [],
            'service_definition': []
        }
        
        current_section = None
        current_content = []
        in_features = False
        in_benefits = False
        in_service_def = False
        current_subsection = None
        
        for para in doc.paragraphs:
            text = para.text.strip()
            if not text:
                continue
            
            # Check if it's a heading
            style = para.style.name if para.style else ''
            
            # Title (Heading 1)
            if style.startswith('Heading 1') or (not result['title'] and len(text) < 100):
                if not result['title']:
                    result['title'] = text
                    continue
            
            # Short Service Description
            if 'Short Service Description' in text or 'short service description' in text.lower():
                current_section = 'description'
                continue
            
            # Key Service Features
            if 'Key Service Features' in text or 'key service features' in text.lower():
                current_section = 'features'
                in_features = True
                in_benefits = False
                in_service_def = False
                continue
            
            # Key Service Benefits
            if 'Key Service Benefits' in text or 'key service benefits' in text.lower():
                current_section = 'benefits'
                in_features = False
                in_benefits = True
                in_service_def = False
                continue
            
            # Service Definition (Heading 3)
            if style.startswith('Heading 3'):
                # Save previous subsection if exists
                if current_subsection:
                    result['service_definition'].append(current_subsection)
                # Start new subsection
                # Replace AI Security advisory with Lorem Ipsum
                subtitle = text
                if 'AI Security' in subtitle or 'advisory' in subtitle.lower() or '1.4.1' in subtitle:
                    subtitle = 'Lorem ipsum dolor sit amet'
                current_subsection = {'subtitle': subtitle, 'content': ''}
                in_features = False
                in_benefits = False
                in_service_def = True
                continue
            
            # Collect content based on current section
            if current_section == 'description' and not in_features and not in_benefits:
                if result['description']:
                    result['description'] += ' ' + text
                else:
                    result['description'] = text
            
            elif in_features:
                # Check if it's a list item (bullet or numbered)
                if para.style.name.startswith('List') or para.style.name.startswith('List Bullet'):
                    result['features'].append(text)
                elif text and not any(keyword in text.lower() for keyword in ['key service', 'short service']):
                    # Not a heading, could be a feature
                    result['features'].append(text)
            
            elif in_benefits:
                # Check if it's a list item
                if para.style.name.startswith('List') or para.style.name.startswith('List Bullet'):
                    result['benefits'].append(text)
                elif text and not any(keyword in text.lower() for keyword in ['key service', 'short service']):
                    # Not a heading, could be a benefit
                    result['benefits'].append(text)
            
            elif in_service_def and current_subsection:
                # Add content to current subsection
                if current_subsection['content']:
                    current_subsection['content'] += ' ' + text
                else:
                    current_subsection['content'] = text
        
        # Save last subsection if exists
        if current_subsection:
            result['service_definition'].append(current_subsection)
        
        # Clean up empty strings
        result['features'] = [f for f in result['features'] if f.strip()]
        result['benefits'] = [b for b in result['benefits'] if b.strip()]
        
        return result
        
    except Exception as e:
        logger.error(f"Error parsing document {doc_path}: {e}")
        raise


def read_document_content(service_name: str, doc_type: str, lot: str, gcloud_version: str = "14") -> Optional[Dict]:
    """
    Read and parse a document from mock SharePoint.
    
    Args:
        service_name: Service name
        doc_type: Document type ("SERVICE DESC" or "Pricing Doc")
        lot: LOT number ("2" or "3")
        gcloud_version: GCloud version ("14" or "15")
        
    Returns:
        Parsed document content or None if not found
    """
    from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH, get_document_path
    
    doc_path = get_document_path(service_name, doc_type, lot, gcloud_version)
    
    if not doc_path or not doc_path.exists():
        return None
    
    if doc_type == "SERVICE DESC":
        return parse_service_description_document(doc_path)
    
    # For other document types, we can extend later
    return None

