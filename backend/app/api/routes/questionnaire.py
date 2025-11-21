"""
Questionnaire API routes for G-Cloud Capabilities Questionnaire
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import logging
import json
from datetime import datetime

from app.services.questionnaire_parser import QuestionnaireParser

logger = logging.getLogger(__name__)

router = APIRouter()

# Initialize parser
_parser = None

def get_parser():
    """Get or create questionnaire parser instance"""
    global _parser
    if _parser is None:
        try:
            _parser = QuestionnaireParser()
        except Exception as e:
            logger.warning(f"Failed to initialize questionnaire parser: {e}")
            _parser = None
    return _parser


# Request/Response models
class QuestionAnswer(BaseModel):
    """Answer to a single question"""
    question_text: str
    question_type: str
    answer: Any  # Can be str, list, or dict
    section_name: str


class QuestionnaireResponseRequest(BaseModel):
    """Request to save questionnaire responses"""
    service_name: str
    lot: str = Field(..., description="LOT number (2a, 2b, or 3)")
    gcloud_version: str = Field(default="15", description="G-Cloud version")
    answers: List[QuestionAnswer]
    is_draft: bool = Field(default=True, description="Whether this is a draft")
    is_locked: bool = Field(default=False, description="Whether responses are locked")


class QuestionnaireResponseResponse(BaseModel):
    """Response with questionnaire data"""
    service_name: str
    lot: str
    gcloud_version: str
    sections: Dict[str, List[Dict[str, Any]]]
    section_order: List[str]
    saved_answers: Optional[Dict[str, Any]] = None
    is_draft: bool = True
    is_locked: bool = False


@router.get("/questions/{lot}", response_model=QuestionnaireResponseResponse)
async def get_questions(
    lot: str,
    service_name: Optional[str] = Query(None, description="Service name to map to questionnaire"),
    gcloud_version: str = Query("15", description="G-Cloud version")
):
    """
    Get questions for a specific LOT, grouped by section
    
    Args:
        lot: LOT number ("3", "2a", or "2b")
        service_name: Optional service name to map to questionnaire
        gcloud_version: G-Cloud version
        
    Returns:
        Questions grouped by section with section order
    """
    try:
        parser = get_parser()
        if not parser:
            raise HTTPException(status_code=500, detail="Questionnaire parser not available")
        
        if lot not in ["3", "2a", "2b"]:
            raise HTTPException(status_code=400, detail=f"Invalid LOT: {lot}. Must be '3', '2a', or '2b'")
        
        # Parse questions grouped by section
        sections = parser.parse_questions_for_lot(lot)
        section_order = parser.get_sections_for_lot(lot)
        
        # Map service name to Service Name question if provided
        if service_name:
            for section_name, questions in sections.items():
                for question in questions:
                    if 'service name' in question['question_text'].lower() or 'service name' in str(question.get('question_text', '')).lower():
                        # Pre-fill service name
                        question['prefilled_answer'] = service_name
                        break
        
        # Try to load saved answers
        saved_answers = None
        is_draft = True
        is_locked = False
        if service_name:
            try:
                saved_answers, is_draft, is_locked = await load_questionnaire_responses(service_name, lot, gcloud_version)
            except Exception as e:
                logger.warning(f"Failed to load saved answers: {e}")
        
        return QuestionnaireResponseResponse(
            service_name=service_name or "",
            lot=lot,
            gcloud_version=gcloud_version,
            sections=sections,
            section_order=section_order,
            saved_answers=saved_answers,
            is_draft=is_draft,
            is_locked=is_locked
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting questions for LOT {lot}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error getting questions: {str(e)}")


@router.post("/responses")
async def save_responses(request: QuestionnaireResponseRequest):
    """
    Save questionnaire responses
    
    Args:
        request: Questionnaire response data
        
    Returns:
        Success status
    """
    try:
        # Save to Azure Blob Storage or local filesystem
        success = await save_questionnaire_responses(
            service_name=request.service_name,
            lot=request.lot,
            gcloud_version=request.gcloud_version,
            answers=request.answers,
            is_draft=request.is_draft,
            is_locked=request.is_locked
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to save questionnaire responses")
        
        return {
            "success": True,
            "message": "Questionnaire responses saved successfully",
            "is_draft": request.is_draft,
            "is_locked": request.is_locked
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving questionnaire responses: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error saving responses: {str(e)}")


@router.get("/responses/{service_name}")
async def get_responses(
    service_name: str,
    lot: str = Query(..., description="LOT number (2a, 2b, or 3)"),
    gcloud_version: str = Query("15", description="G-Cloud version")
):
    """
    Get saved questionnaire responses for a service
    
    Args:
        service_name: Service name
        lot: LOT number
        gcloud_version: G-Cloud version
        
    Returns:
        Saved responses with status
    """
    try:
        answers, is_draft, is_locked = await load_questionnaire_responses(service_name, lot, gcloud_version)
        
        return {
            "service_name": service_name,
            "lot": lot,
            "gcloud_version": gcloud_version,
            "answers": answers,
            "is_draft": is_draft,
            "is_locked": is_locked
        }
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Questionnaire responses not found")
    except Exception as e:
        logger.error(f"Error getting questionnaire responses: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error getting responses: {str(e)}")


async def save_questionnaire_responses(
    service_name: str,
    lot: str,
    gcloud_version: str,
    answers: List[QuestionAnswer],
    is_draft: bool,
    is_locked: bool
) -> bool:
    """
    Save questionnaire responses to storage
    
    Args:
        service_name: Service name
        lot: LOT number
        gcloud_version: G-Cloud version
        answers: List of answers
        is_draft: Whether this is a draft
        is_locked: Whether responses are locked
        
    Returns:
        True if successful
    """
    import os
    from pathlib import Path
    
    # Check if we're in Azure
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    # Prepare response data
    response_data = {
        "service_name": service_name,
        "lot": lot,
        "gcloud_version": gcloud_version,
        "answers": [answer.dict() for answer in answers],
        "is_draft": is_draft,
        "is_locked": is_locked,
        "updated_at": datetime.utcnow().isoformat()
    }
    
    if use_azure:
        # Save to Azure Blob Storage
        try:
            from app.services.azure_blob_service import AzureBlobService
            azure_blob_service = AzureBlobService()
            
            # Construct blob key: GCloud {version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json
            blob_key = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json"
            
            # Save as JSON string
            json_data = json.dumps(response_data, indent=2)
            
            # Write to temporary file then upload
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                f.write(json_data)
                temp_path = Path(f.name)
            
            try:
                azure_blob_service.upload_file(temp_path, blob_key)
                return True
            finally:
                # Clean up temp file
                if temp_path.exists():
                    temp_path.unlink()
                    
        except Exception as e:
            logger.error(f"Failed to save to Azure Blob Storage: {e}")
            return False
    else:
        # Save to local filesystem
        try:
            from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH
            
            # Construct path: mock_sharepoint/GCloud {version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json
            response_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot}" / service_name / "questionnaire_responses.json"
            
            # Ensure directory exists
            response_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write JSON file
            with open(response_path, 'w', encoding='utf-8') as f:
                json.dump(response_data, f, indent=2)
            
            return True
        except Exception as e:
            logger.error(f"Failed to save to local filesystem: {e}")
            return False


async def load_questionnaire_responses(
    service_name: str,
    lot: str,
    gcloud_version: str
) -> tuple[Dict[str, Any], bool, bool]:
    """
    Load questionnaire responses from storage
    
    Args:
        service_name: Service name
        lot: LOT number
        gcloud_version: G-Cloud version
        
    Returns:
        Tuple of (answers dict, is_draft, is_locked)
    """
    import os
    from pathlib import Path
    
    # Check if we're in Azure
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    if use_azure:
        # Load from Azure Blob Storage
        try:
            from app.services.azure_blob_service import AzureBlobService
            azure_blob_service = AzureBlobService()
            
            # Construct blob key
            blob_key = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot}/{service_name}/questionnaire_responses.json"
            
            if not azure_blob_service.blob_exists(blob_key):
                raise FileNotFoundError(f"Questionnaire responses not found: {blob_key}")
            
            # Get file bytes
            json_bytes = azure_blob_service.get_file_bytes(blob_key)
            response_data = json.loads(json_bytes.decode('utf-8'))
            
            # Convert answers list to dict keyed by question text
            answers_dict = {}
            for answer in response_data.get('answers', []):
                question_text = answer.get('question_text', '')
                answers_dict[question_text] = answer.get('answer')
            
            return (
                answers_dict,
                response_data.get('is_draft', True),
                response_data.get('is_locked', False)
            )
        except Exception as e:
            logger.error(f"Failed to load from Azure Blob Storage: {e}")
            raise
    else:
        # Load from local filesystem
        try:
            from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH
            
            response_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot}" / service_name / "questionnaire_responses.json"
            
            if not response_path.exists():
                raise FileNotFoundError(f"Questionnaire responses not found: {response_path}")
            
            with open(response_path, 'r', encoding='utf-8') as f:
                response_data = json.load(f)
            
            # Convert answers list to dict keyed by question text
            answers_dict = {}
            for answer in response_data.get('answers', []):
                question_text = answer.get('question_text', '')
                answers_dict[question_text] = answer.get('answer')
            
            return (
                answers_dict,
                response_data.get('is_draft', True),
                response_data.get('is_locked', False)
            )
        except Exception as e:
            logger.error(f"Failed to load from local filesystem: {e}")
            raise

