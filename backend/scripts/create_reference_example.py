"""
Script to create a reference example document showing correct template format.
"""

import sys
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.document_generator import DocumentGenerator
import shutil

def create_reference_example():
    """Create a reference example document"""
    
    generator = DocumentGenerator()
    
    result = generator.generate_service_description(
        title='Reference Example Service',
        description='This is a reference example document showing the correct template format and formatting. Use this as a reference for future document generation. The document demonstrates proper formatting, structure, and content placement within the G-Cloud Service Description template.',
        features=[
            'Feature 1: Comprehensive service feature description',
            'Feature 2: Advanced technical capability demonstration',
            'Feature 3: Professional service delivery method'
        ],
        benefits=[
            'Benefit 1: Significant improvement in service delivery',
            'Benefit 2: Enhanced operational efficiency and effectiveness',
            'Benefit 3: Reduced costs and improved stakeholder satisfaction'
        ],
        service_definition=[
            {
                'subtitle': 'Service Subsection 1',
                'content': 'This is sample content for a service subsection. It demonstrates how service definition subsections should be formatted and structured within the document.'
            },
            {
                'subtitle': 'Service Subsection 2',
                'content': 'This is additional sample content showing how multiple subsections appear in the service definition section. Each subsection should have a clear subtitle and descriptive content.'
            }
        ]
    )
    
    print(f"Reference example saved to: {result['word_path']}")
    
    # Copy to reference location
    ref_path = Path(__file__).parent.parent / "reference_example_service_description.docx"
    shutil.copy2(result['word_path'], ref_path)
    print(f"Copied to: {ref_path}")
    
    return ref_path

if __name__ == "__main__":
    create_reference_example()

