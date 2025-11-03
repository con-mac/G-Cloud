"""
PDF Converter Lambda Function
Converts Word documents to PDF using Python libraries
(Simplified approach without LibreOffice for Lambda compatibility)
"""

import os
import json
import boto3
from pathlib import Path
from docx import Document
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

s3_client = boto3.client('s3')

OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET_NAME')


def extract_text_from_docx(docx_path):
    """
    Extract text content from DOCX file
    Returns structured content with headings and paragraphs
    """
    doc = Document(str(docx_path))
    content = []
    
    for element in doc.element.body:
        # Check if it's a paragraph
        if element.tag.endswith('p'):
            para = None
            for p in doc.paragraphs:
                if p._element == element:
                    para = p
                    break
            
            if para:
                text = para.text.strip()
                if text:
                    style_name = para.style.name if para.style else 'Normal'
                    content.append({
                        'text': text,
                        'style': style_name,
                        'is_heading': style_name.startswith('Heading'),
                        'level': int(style_name.split()[-1]) if style_name.split()[-1].isdigit() else 0
                    })
    
    return content


def create_pdf_from_content(content, pdf_path):
    """
    Create PDF from extracted content using ReportLab
    """
    doc = SimpleDocTemplate(str(pdf_path), pagesize=A4)
    styles = getSampleStyleSheet()
    story = []
    
    # Create custom styles
    heading_style = ParagraphStyle(
        'CustomHeading1',
        parent=styles['Heading1'],
        fontSize=18,
        spaceAfter=12,
        alignment=TA_LEFT
    )
    
    for item in content:
        text = item['text']
        
        if item['is_heading']:
            if item['level'] == 1:
                story.append(Paragraph(text, heading_style))
            elif item['level'] == 2:
                story.append(Paragraph(text, styles['Heading2']))
            else:
                story.append(Paragraph(text, styles['Heading3']))
            story.append(Spacer(1, 0.2 * inch))
        else:
            story.append(Paragraph(text, styles['Normal']))
            story.append(Spacer(1, 0.1 * inch))
    
    doc.build(story)


def handler(event, context):
    """
    Lambda handler for PDF conversion
    
    Expected event format:
    {
        "word_s3_key": "generated/document_name.docx",
        "word_bucket": "output-bucket-name"
    }
    
    Returns:
    {
        "success": bool,
        "pdf_s3_key": "generated/document_name.pdf",
        "pdf_url": "presigned_url"
    }
    """
    try:
        # Parse input
        if isinstance(event, str):
            event = json.loads(event)
        
        word_s3_key = event.get('word_s3_key')
        word_bucket = event.get('word_bucket', OUTPUT_BUCKET)
        
        if not word_s3_key:
            raise ValueError("word_s3_key is required")
        
        if not word_bucket:
            raise ValueError("word_bucket is required")
        
        # Create temp directories
        input_dir = Path('/tmp/input')
        output_dir = Path('/tmp/output')
        input_dir.mkdir(parents=True, exist_ok=True)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Download Word document from S3
        word_filename = Path(word_s3_key).name
        local_word_path = input_dir / word_filename
        s3_client.download_file(word_bucket, word_s3_key, str(local_word_path))
        
        # Extract content from DOCX
        content = extract_text_from_docx(local_word_path)
        
        # Convert to PDF
        pdf_filename = word_filename.replace('.docx', '.pdf')
        local_pdf_path = output_dir / pdf_filename
        
        create_pdf_from_content(content, local_pdf_path)
        
        # Check if PDF was created
        if not local_pdf_path.exists():
            raise FileNotFoundError(f"PDF not generated: {local_pdf_path}")
        
        # Upload PDF to S3
        pdf_s3_key = word_s3_key.replace('.docx', '.pdf')
        s3_client.upload_file(
            str(local_pdf_path),
            word_bucket,
            pdf_s3_key,
            ExtraArgs={'ContentType': 'application/pdf'}
        )
        
        # Generate presigned URL for PDF
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': word_bucket, 'Key': pdf_s3_key},
            ExpiresIn=3600
        )
        
        # Cleanup
        local_word_path.unlink(missing_ok=True)
        local_pdf_path.unlink(missing_ok=True)
        
        return {
            'success': True,
            'pdf_s3_key': pdf_s3_key,
            'pdf_url': presigned_url
        }
        
    except Exception as e:
        import traceback
        return {
            'success': False,
            'error': str(e),
            'traceback': traceback.format_exc()
        }
