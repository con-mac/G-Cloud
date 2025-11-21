"""
Analytics API routes for questionnaire responses
Provides aggregated analytics and drill-down functionality for admin dashboard
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import logging
import json
import os
from pathlib import Path
from collections import defaultdict, Counter

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


class QuestionAnalytics(BaseModel):
    """Analytics for a single question"""
    question_text: str
    question_type: str
    section_name: str
    answer_counts: Dict[str, int]  # answer_value -> count
    total_responses: int
    services_by_answer: Dict[str, List[str]]  # answer_value -> list of service names


class SectionAnalytics(BaseModel):
    """Analytics for a section"""
    section_name: str
    questions: List[QuestionAnalytics]
    total_questions: int
    completed_services: int


class ServiceStatus(BaseModel):
    """Status of a service's questionnaire"""
    service_name: str
    lot: str
    gcloud_version: str
    has_responses: bool
    is_draft: bool
    is_locked: bool
    completion_percentage: float
    last_updated: Optional[str] = None


class AnalyticsSummary(BaseModel):
    """Summary of all analytics"""
    total_services: int
    services_with_responses: int
    services_without_responses: int
    services_locked: int
    services_draft: int
    lot_breakdown: Dict[str, int]  # lot -> count
    sections: List[SectionAnalytics]


@router.get("/summary", response_model=AnalyticsSummary)
async def get_analytics_summary(
    lot: Optional[str] = Query(None, description="Filter by LOT (2a, 2b, 3)"),
    gcloud_version: str = Query("15", description="G-Cloud version")
):
    """
    Get overall analytics summary for questionnaire responses
    
    Returns:
        Summary with counts and breakdowns
    """
    try:
        # Get all services and their questionnaire status
        services_status = await get_all_services_status(lot, gcloud_version)
        
        # Get all questionnaire responses
        all_responses = await get_all_questionnaire_responses(lot, gcloud_version)
        
        # Aggregate by section and question
        sections_analytics = await aggregate_responses_by_section(all_responses, lot, gcloud_version)
        
        # Calculate summary stats
        total_services = len(services_status)
        services_with_responses = len([s for s in services_status if s.has_responses])
        services_without_responses = total_services - services_with_responses
        services_locked = len([s for s in services_status if s.is_locked])
        services_draft = len([s for s in services_status if s.is_draft and not s.is_locked])
        
        # LOT breakdown
        lot_breakdown = defaultdict(int)
        for service in services_status:
            lot_breakdown[service.lot] += 1
        
        return AnalyticsSummary(
            total_services=total_services,
            services_with_responses=services_with_responses,
            services_without_responses=services_without_responses,
            services_locked=services_locked,
            services_draft=services_draft,
            lot_breakdown=dict(lot_breakdown),
            sections=sections_analytics
        )
    except Exception as e:
        logger.error(f"Error getting analytics summary: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error getting analytics: {str(e)}")


@router.get("/services", response_model=List[ServiceStatus])
async def get_services_status(
    lot: Optional[str] = Query(None, description="Filter by LOT (2a, 2b, 3)"),
    gcloud_version: str = Query("15", description="G-Cloud version")
):
    """
    Get status of all services regarding questionnaire completion
    
    Returns:
        List of service statuses
    """
    try:
        services = await get_all_services_status(lot, gcloud_version)
        return services
    except Exception as e:
        logger.error(f"Error getting services status: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error getting services status: {str(e)}")


@router.get("/drill-down/{section_name}/{question_text:path}")
async def get_drill_down(
    section_name: str,
    question_text: str,
    lot: Optional[str] = Query(None, description="Filter by LOT (2a, 2b, 3)"),
    gcloud_version: str = Query("15", description="G-Cloud version")
):
    """
    Get drill-down data for a specific question showing which services answered what
    
    Args:
        section_name: Section name
        question_text: Question text (URL encoded)
        lot: Optional LOT filter
        gcloud_version: G-Cloud version
        
    Returns:
        Detailed breakdown by answer value with service names
    """
    try:
        # Get all responses
        all_responses = await get_all_questionnaire_responses(lot, gcloud_version)
        
        # Find the specific question
        question_responses = {}
        for response in all_responses:
            service_name = response['service_name']
            lot_val = response['lot']
            answers = response.get('answers', [])
            
            for answer in answers:
                if (answer.get('section_name') == section_name and 
                    answer.get('question_text') == question_text):
                    answer_value = answer.get('answer')
                    # Convert answer to string key for grouping
                    if isinstance(answer_value, list):
                        answer_key = ', '.join(str(v) for v in answer_value)
                    else:
                        answer_key = str(answer_value) if answer_value else 'No answer'
                    
                    if answer_key not in question_responses:
                        question_responses[answer_key] = []
                    question_responses[answer_key].append({
                        'service_name': service_name,
                        'lot': lot_val
                    })
        
        return {
            'section_name': section_name,
            'question_text': question_text,
            'breakdown': question_responses,
            'total_services': sum(len(services) for services in question_responses.values())
        }
    except Exception as e:
        logger.error(f"Error getting drill-down: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error getting drill-down: {str(e)}")


async def get_all_services_status(
    lot: Optional[str],
    gcloud_version: str
) -> List[ServiceStatus]:
    """
    Get status of all services (with and without questionnaire responses)
    
    Returns:
        List of ServiceStatus objects
    """
    services_status = []
    
    # Check if we're in Azure
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    if use_azure:
        from app.services.azure_blob_service import AzureBlobService
        azure_blob_service = AzureBlobService()
        
        # Get all service folders
        lots_to_check = [lot] if lot else ["2", "2a", "2b", "3"]
        
        for lot_val in lots_to_check:
            base_prefix = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot_val}/"
            blob_list = azure_blob_service.list_blobs(prefix=base_prefix)
            
            # Extract unique service folder names
            service_folders = set()
            for blob_name in blob_list:
                parts = blob_name.split('/')
                if len(parts) >= 4:
                    service_folders.add(parts[3])
            
            # Check each service for questionnaire responses
            for service_name in service_folders:
                response_blob = f"{base_prefix}{service_name}/questionnaire_responses.json"
                
                has_responses = azure_blob_service.blob_exists(response_blob)
                is_draft = True
                is_locked = False
                last_updated = None
                
                if has_responses:
                    try:
                        json_bytes = azure_blob_service.get_file_bytes(response_blob)
                        response_data = json.loads(json_bytes.decode('utf-8'))
                        is_draft = response_data.get('is_draft', True)
                        is_locked = response_data.get('is_locked', False)
                        last_updated = response_data.get('updated_at')
                        
                        # Calculate completion percentage
                        answers = response_data.get('answers', [])
                        parser = get_parser()
                        if parser:
                            questions = parser.parse_questions_for_lot(lot_val)
                            total_questions = sum(len(q_list) for q_list in questions.values())
                            completion_percentage = (len(answers) / total_questions * 100) if total_questions > 0 else 0
                        else:
                            completion_percentage = 100 if not is_draft else 50
                    except Exception as e:
                        logger.warning(f"Failed to parse questionnaire for {service_name}: {e}")
                        completion_percentage = 0
                else:
                    completion_percentage = 0
                
                services_status.append(ServiceStatus(
                    service_name=service_name,
                    lot=lot_val,
                    gcloud_version=gcloud_version,
                    has_responses=has_responses,
                    is_draft=is_draft,
                    is_locked=is_locked,
                    completion_percentage=completion_percentage,
                    last_updated=last_updated
                ))
    else:
        # Local filesystem
        from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH
        
        lots_to_check = [lot] if lot else ["2", "2a", "2b", "3"]
        
        for lot_val in lots_to_check:
            base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot_val}"
            
            if not base_path.exists():
                continue
            
            # Get all service folders
            for service_folder in base_path.iterdir():
                if not service_folder.is_dir():
                    continue
                
                service_name = service_folder.name
                response_path = service_folder / "questionnaire_responses.json"
                
                has_responses = response_path.exists()
                is_draft = True
                is_locked = False
                last_updated = None
                
                if has_responses:
                    try:
                        with open(response_path, 'r', encoding='utf-8') as f:
                            response_data = json.load(f)
                        is_draft = response_data.get('is_draft', True)
                        is_locked = response_data.get('is_locked', False)
                        last_updated = response_data.get('updated_at')
                        
                        # Calculate completion percentage
                        answers = response_data.get('answers', [])
                        parser = get_parser()
                        if parser:
                            questions = parser.parse_questions_for_lot(lot_val)
                            total_questions = sum(len(q_list) for q_list in questions.values())
                            completion_percentage = (len(answers) / total_questions * 100) if total_questions > 0 else 0
                        else:
                            completion_percentage = 100 if not is_draft else 50
                    except Exception as e:
                        logger.warning(f"Failed to parse questionnaire for {service_name}: {e}")
                        completion_percentage = 0
                else:
                    completion_percentage = 0
                
                services_status.append(ServiceStatus(
                    service_name=service_name,
                    lot=lot_val,
                    gcloud_version=gcloud_version,
                    has_responses=has_responses,
                    is_draft=is_draft,
                    is_locked=is_locked,
                    completion_percentage=completion_percentage,
                    last_updated=last_updated
                ))
    
    return services_status


async def get_all_questionnaire_responses(
    lot: Optional[str],
    gcloud_version: str
) -> List[Dict[str, Any]]:
    """
    Load all questionnaire responses from storage
    
    Returns:
        List of response dictionaries
    """
    all_responses = []
    
    # Check if we're in Azure
    use_azure = bool(os.environ.get("AZURE_STORAGE_CONNECTION_STRING", ""))
    
    if use_azure:
        from app.services.azure_blob_service import AzureBlobService
        azure_blob_service = AzureBlobService()
        
        lots_to_check = [lot] if lot else ["2", "2a", "2b", "3"]
        
        for lot_val in lots_to_check:
            base_prefix = f"GCloud {gcloud_version}/PA Services/Cloud Support Services LOT {lot_val}/"
            blob_list = azure_blob_service.list_blobs(prefix=base_prefix)
            
            # Find all questionnaire_responses.json files
            for blob_name in blob_list:
                if blob_name.endswith('questionnaire_responses.json'):
                    try:
                        json_bytes = azure_blob_service.get_file_bytes(blob_name)
                        response_data = json.loads(json_bytes.decode('utf-8'))
                        
                        # Extract service name from blob path
                        parts = blob_name.split('/')
                        service_name = parts[3] if len(parts) > 3 else 'Unknown'
                        
                        response_data['service_name'] = service_name
                        response_data['lot'] = lot_val
                        all_responses.append(response_data)
                    except Exception as e:
                        logger.warning(f"Failed to load questionnaire from {blob_name}: {e}")
    else:
        # Local filesystem
        from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH
        
        lots_to_check = [lot] if lot else ["2", "2a", "2b", "3"]
        
        for lot_val in lots_to_check:
            base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot_val}"
            
            if not base_path.exists():
                continue
            
            for service_folder in base_path.iterdir():
                if not service_folder.is_dir():
                    continue
                
                response_path = service_folder / "questionnaire_responses.json"
                
                if response_path.exists():
                    try:
                        with open(response_path, 'r', encoding='utf-8') as f:
                            response_data = json.load(f)
                        
                        response_data['service_name'] = service_folder.name
                        response_data['lot'] = lot_val
                        all_responses.append(response_data)
                    except Exception as e:
                        logger.warning(f"Failed to load questionnaire from {response_path}: {e}")
    
    return all_responses


async def aggregate_responses_by_section(
    all_responses: List[Dict[str, Any]],
    lot: Optional[str],
    gcloud_version: str
) -> List[SectionAnalytics]:
    """
    Aggregate responses by section and question
    
    Returns:
        List of SectionAnalytics
    """
    # Get question structure from parser
    parser = get_parser()
    if not parser:
        return []
    
    # Get sections for the LOT (or all LOTs)
    lots_to_check = [lot] if lot else ["2", "2a", "2b", "3"]
    
    sections_analytics = []
    
    for lot_val in lots_to_check:
        questions_by_section = parser.parse_questions_for_lot(lot_val)
        section_order = parser.get_sections_for_lot(lot_val)
        
        # Filter responses for this LOT
        lot_responses = [r for r in all_responses if r.get('lot') == lot_val]
        
        # Aggregate by section
        for section_name in section_order:
            questions = questions_by_section.get(section_name, [])
            question_analytics = []
            
            for question in questions:
                question_text = question.get('question_text', '')
                question_type = question.get('question_type', '')
                
                # Count answers for this question
                answer_counts = Counter()
                services_by_answer = defaultdict(list)
                
                for response in lot_responses:
                    service_name = response['service_name']
                    answers = response.get('answers', [])
                    
                    # Find matching answer
                    for answer in answers:
                        if answer.get('question_text') == question_text:
                            answer_value = answer.get('answer')
                            
                            # Convert to string key
                            if isinstance(answer_value, list):
                                answer_key = ', '.join(str(v) for v in answer_value)
                            else:
                                answer_key = str(answer_value) if answer_value else 'No answer'
                            
                            answer_counts[answer_key] += 1
                            services_by_answer[answer_key].append(service_name)
                            break
                
                question_analytics.append(QuestionAnalytics(
                    question_text=question_text,
                    question_type=question_type,
                    section_name=section_name,
                    answer_counts=dict(answer_counts),
                    total_responses=sum(answer_counts.values()),
                    services_by_answer={k: list(set(v)) for k, v in services_by_answer.items()}  # Deduplicate
                ))
            
            # Count completed services for this section
            completed_services = set()
            for response in lot_responses:
                answers = response.get('answers', [])
                section_answers = [a for a in answers if a.get('section_name') == section_name]
                if section_answers:
                    completed_services.add(response['service_name'])
            
            sections_analytics.append(SectionAnalytics(
                section_name=section_name,
                questions=question_analytics,
                total_questions=len(question_analytics),
                completed_services=len(completed_services)
            ))
    
    return sections_analytics

