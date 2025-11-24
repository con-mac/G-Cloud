"""
Script to seed questionnaire data for testing admin analytics dashboard
Creates sample questionnaire responses for different services and LOTs
"""

import os
import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.questionnaire_parser import QuestionnaireParser

# Sample services and their data
SAMPLE_SERVICES = [
    {
        "service_name": "Cloud Infrastructure Services",
        "lot": "3",
        "gcloud_version": "15",
        "completion_status": "completed",
        "is_locked": True,
    },
    {
        "service_name": "Data Analytics Platform",
        "lot": "2a",
        "gcloud_version": "15",
        "completion_status": "completed",
        "is_locked": True,
    },
    {
        "service_name": "Customer Relationship Management",
        "lot": "2b",
        "gcloud_version": "15",
        "completion_status": "draft",
        "is_locked": False,
    },
    {
        "service_name": "Security Monitoring Service",
        "lot": "3",
        "gcloud_version": "15",
        "completion_status": "completed",
        "is_locked": False,
    },
    {
        "service_name": "Business Intelligence Tool",
        "lot": "2a",
        "gcloud_version": "15",
        "completion_status": "draft",
        "is_locked": False,
    },
]


def generate_sample_answers(parser: QuestionnaireParser, lot: str, service_name: str) -> List[Dict[str, Any]]:
    """Generate sample answers for a questionnaire"""
    sections = parser.parse_questions_for_lot(lot)
    answers = []
    
    for section_name, questions in sections.items():
        for question in questions:
            question_text = question.get('question_text', '')
            question_type = question.get('question_type', 'text')
            answer_options = question.get('answer_options', [])
            
            # Generate sample answer based on question type
            answer_value = None
            
            if question_type == 'text' or question_type == 'Text field':
                if 'service name' in question_text.lower() or 'service called' in question_text.lower():
                    answer_value = service_name
                elif 'service type' in question_text.lower():
                    answer_value = "Cloud Support Service"
                else:
                    answer_value = f"Sample answer for {question_text[:30]}"
            
            elif question_type == 'textarea' or question_type == 'Textarea':
                answer_value = f"This is a sample detailed response for the question: {question_text[:50]}. It provides comprehensive information about the service capabilities and features."
            
            elif question_type == 'radio' or question_type == 'Radio buttons':
                if answer_options:
                    answer_value = answer_options[0]  # Select first option
                else:
                    answer_value = "Yes"
            
            elif question_type == 'checkbox' or question_type == 'Grouped checkboxes':
                if answer_options:
                    # Select first 2-3 options
                    answer_value = answer_options[:min(3, len(answer_options))]
                else:
                    answer_value = ["Option 1", "Option 2"]
            
            elif question_type == 'list' or question_type == 'List of text fields':
                # Generate 3-5 sample list items
                answer_value = [
                    "Sample requirement item one",
                    "Sample requirement item two",
                    "Sample requirement item three"
                ]
                # Add more if it's systems requirements
                if 'systems requirements' in question_text.lower():
                    answer_value = [
                        "Windows 10 or later",
                        "Minimum 4GB RAM",
                        "Internet connection required",
                        "Modern web browser",
                        "Active directory integration"
                    ]
            
            if answer_value is not None:
                answers.append({
                    "question_text": question_text,
                    "question_type": question_type,
                    "answer": answer_value,
                    "section_name": section_name
                })
    
    return answers


def save_questionnaire_response(
    service_name: str,
    lot: str,
    gcloud_version: str,
    answers: List[Dict[str, Any]],
    is_draft: bool,
    is_locked: bool,
    use_azure: bool
):
    """Save questionnaire response to storage"""
    response_data = {
        "service_name": service_name,
        "lot": lot,
        "gcloud_version": gcloud_version,
        "answers": answers,
        "is_draft": is_draft,
        "is_locked": is_locked,
        "updated_at": (datetime.utcnow() - timedelta(days=len(answers) % 7)).isoformat()  # Vary dates
    }
    
    if use_azure:
        from app.services.azure_blob_service import AzureBlobService
        azure_blob_service = AzureBlobService()
        
        blob_key = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json"
        
        json_data = json.dumps(response_data, indent=2)
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write(json_data)
            temp_path = Path(f.name)
        
        try:
            azure_blob_service.upload_file(temp_path, blob_key)
            print(f"✅ Saved to Azure: {blob_key}")
        finally:
            if temp_path.exists():
                temp_path.unlink()
    else:
        # Local filesystem
        from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH
        
        response_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot}" / service_name / "questionnaire_responses.json"
        
        response_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(response_path, 'w', encoding='utf-8') as f:
            json.dump(response_data, f, indent=2)
        
        print(f"✅ Saved to local: {response_path}")


def main():
    """Main function to seed questionnaire data"""
    print("🌱 Seeding questionnaire data for testing...")
    
    # Check if we're in Azure
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    if use_azure:
        print("📦 Using Azure Blob Storage")
    else:
        print("💾 Using local filesystem")
    
    # Initialize parser
    try:
        parser = QuestionnaireParser()
        print("✅ Questionnaire parser initialized")
    except Exception as e:
        print(f"❌ Failed to initialize parser: {e}")
        return
    
    # Generate and save responses for each service
    for service in SAMPLE_SERVICES:
        print(f"\n📝 Processing: {service['service_name']} (LOT {service['lot']})")
        
        try:
            # Generate answers
            answers = generate_sample_answers(
                parser,
                service['lot'],
                service['service_name']
            )
            
            print(f"   Generated {len(answers)} answers")
            
            # Save response
            save_questionnaire_response(
                service_name=service['service_name'],
                lot=service['lot'],
                gcloud_version=service['gcloud_version'],
                answers=answers,
                is_draft=(service['completion_status'] == 'draft'),
                is_locked=service['is_locked'],
                use_azure=use_azure
            )
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
            import traceback
            traceback.print_exc()
    
    print("\n✅ Seeding complete!")
    print(f"   Created {len(SAMPLE_SERVICES)} sample questionnaire responses")


if __name__ == "__main__":
    main()

