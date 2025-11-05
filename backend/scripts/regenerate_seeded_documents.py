"""
Script to regenerate all seeded documents in mock_sharepoint using the correct template.
"""

from pathlib import Path
import sys
import os

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.document_generator import DocumentGenerator

def regenerate_seeded_documents():
    """Regenerate all seeded documents with correct template"""
    
    mock_base = Path(__file__).parent.parent.parent / "mock_sharepoint"
    
    if not mock_base.exists():
        print(f"Mock SharePoint base not found: {mock_base}")
        return
    
    # Sample data for seeded documents
    sample_data = {
        "Test Title": {
            "title": "Test Title",
            "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.",
            "features": [
                "Lorem ipsum dolor sit amet",
                "Consectetur adipiscing elit",
                "Sed do eiusmod tempor incididunt",
                "Ut labore et dolore magna aliqua"
            ],
            "benefits": [
                "Ut enim ad minim veniam",
                "Quis nostrud exercitation",
                "Ullamco laboris nisi ut aliquip",
                "Ex ea commodo consequat"
            ],
            "service_definition": [
                {
                    "subtitle": "Lorem ipsum dolor sit amet",
                    "content": "Consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                }
            ]
        },
        "Agile Test Title": {
            "title": "Agile Test Title",
            "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "features": [
                "Lorem ipsum dolor sit amet",
                "Consectetur adipiscing elit",
                "Sed do eiusmod tempor incididunt"
            ],
            "benefits": [
                "Ut enim ad minim veniam",
                "Quis nostrud exercitation",
                "Ullamco laboris nisi ut aliquip"
            ],
            "service_definition": [
                {
                    "subtitle": "Lorem ipsum dolor sit amet",
                    "content": "Consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                }
            ]
        },
        "Test Title v2": {
            "title": "Test Title v2",
            "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.",
            "features": [
                "Lorem ipsum dolor sit amet",
                "Consectetur adipiscing elit",
                "Sed do eiusmod tempor incididunt",
                "Ut labore et dolore magna aliqua"
            ],
            "benefits": [
                "Ut enim ad minim veniam",
                "Quis nostrud exercitation",
                "Ullamco laboris nisi ut aliquip",
                "Ex ea commodo consequat"
            ],
            "service_definition": [
                {
                    "subtitle": "Lorem ipsum dolor sit amet",
                    "content": "Consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                }
            ]
        }
    }
    
    generator = DocumentGenerator()
    
    # Find all service folders and regenerate documents
    for gcloud_version in ["14", "15"]:
        base_path = mock_base / f"GCloud {gcloud_version}" / "PA Services"
        if not base_path.exists():
            continue
        
        for lot in ["2", "3"]:
            lot_folder = base_path / f"Cloud Support Services LOT {lot}"
            if not lot_folder.exists():
                continue
            
            for service_folder in lot_folder.iterdir():
                if not service_folder.is_dir():
                    continue
                
                service_name = service_folder.name
                
                # Get sample data for this service or use default
                data = sample_data.get(service_name, {
                    "title": service_name,
                    "description": f"Sample service description for {service_name}.",
                    "features": ["Feature 1", "Feature 2", "Feature 3"],
                    "benefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
                    "service_definition": [
                        {
                            "subtitle": "Lorem ipsum dolor sit amet",
                            "content": f"Consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
                        }
                    ]
                })
                
                # Update metadata for regeneration
                update_metadata = {
                    "service_name": service_name,
                    "lot": lot,
                    "doc_type": "SERVICE DESC",
                    "gcloud_version": gcloud_version,
                    "folder_path": str(service_folder)
                }
                
                print(f"Regenerating: {service_name} (GCloud {gcloud_version}, LOT {lot})")
                
                try:
                    result = generator.generate_service_description(
                        title=data["title"],
                        description=data["description"],
                        features=data["features"],
                        benefits=data["benefits"],
                        service_definition=data["service_definition"],
                        update_metadata=update_metadata
                    )
                    print(f"  ✅ Success: {result.get('word_path', 'N/A')}")
                except Exception as e:
                    print(f"  ❌ Error: {e}")
    
    print("\n✅ All seeded documents regenerated!")

if __name__ == "__main__":
    regenerate_seeded_documents()

