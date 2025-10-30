"""
Document generation service for G-Cloud proposals
Generates Word and PDF documents from templates
"""

import os
import shutil
from pathlib import Path
from typing import Dict, List
from docx import Document
from docx.shared import Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
import uuid


class DocumentGenerator:
    """Generates G-Cloud proposal documents from templates"""
    
    def __init__(self):
        self.templates_dir = Path("/app/templates")
        self.output_dir = Path("/app/generated_documents")
        self.output_dir.mkdir(parents=True, exist_ok=True)
    
    def generate_service_description(
        self,
        title: str,
        description: str,
        features: List[str],
        benefits: List[str]
    ) -> Dict[str, str]:
        """
        Generate Service Description document from template
        
        Args:
            title: Service name/title
            description: Short service description (500 words max)
            features: List of service features (10 words each, max 10)
            benefits: List of service benefits (10 words each, max 10)
        
        Returns:
            Dict with paths to generated Word and PDF files
        """
        
        # Load template
        template_path = self.templates_dir / "service_description_template.docx"
        if not template_path.exists():
            raise FileNotFoundError(f"Template not found: {template_path}")
        
        # Create a copy to work with
        doc = Document(str(template_path))
        
        # Replace title (first Heading 1)
        self._replace_title(doc, title)
        
        # Replace description, features, and benefits
        self._replace_content_sections(doc, description, features, benefits)
        
        # Generate unique filename
        doc_id = str(uuid.uuid4())[:8]
        safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_'))[:50]
        filename_base = f"{safe_title}_{doc_id}"
        
        # Save Word document
        word_path = self.output_dir / f"{filename_base}.docx"
        doc.save(str(word_path))
        
        # For now, PDF generation would require LibreOffice or similar
        # We'll create a placeholder PDF path
        pdf_path = self.output_dir / f"{filename_base}.pdf"
        
        return {
            "word_path": str(word_path),
            "pdf_path": str(pdf_path),
            "filename": filename_base
        }
    
    def _replace_title(self, doc: Document, new_title: str):
        """Replace the first Heading 1 with the new title"""
        replaced = False
        for paragraph in doc.paragraphs:
            if paragraph.style.name == 'Heading 1':
                # Found the title, replace it
                paragraph.text = new_title
                # Preserve formatting
                for run in paragraph.runs:
                    run.font.size = Pt(24)
                    run.font.bold = True
                replaced = True
                break

        # Fallback: replace literal occurrences of common sample title text in runs
        if not replaced:
            for p in doc.paragraphs:
                for r in p.runs:
                    if r.text and 'AI Security' in r.text:
                        r.text = r.text.replace('AI Security', new_title)
    
    def _replace_content_sections(
        self,
        doc: Document,
        description: str,
        features: List[str],
        benefits: List[str]
    ):
        """
        Replace content in the template sections
        
        Finds "Short Service Description", "Key Service Features", "Key Service Benefits"
        headings and replaces the content that follows them.
        """
        
        # Track which section we're in
        current_section = None
        section_start_idx = None
        
        for i, paragraph in enumerate(doc.paragraphs):
            text = paragraph.text.strip()
            
            # Detect section headings
            if 'Short Service Description' in text:
                current_section = 'description'
                section_start_idx = i
                # Clear existing content under this heading
                self._clear_section_after_heading(doc, i)
                # Replace content after this heading
                self._insert_description(doc, i + 1, description)
                
            elif 'Key Service Features' in text:
                current_section = 'features'
                section_start_idx = i
                self._clear_section_after_heading(doc, i)
                # Replace content after this heading
                self._insert_bullet_list(doc, i + 1, features)
                
            elif 'Key Service Benefits' in text:
                current_section = 'benefits'
                section_start_idx = i
                self._clear_section_after_heading(doc, i)
                # Replace content after this heading
                self._insert_bullet_list(doc, i + 1, benefits)

    def _clear_section_after_heading(self, doc: Document, heading_idx: int):
        """Remove paragraphs following a heading until the next heading or end of document.

        Note: python-docx doesn't support deleting list items as a group, so we remove
        underlying elements paragraph by paragraph.
        """
        i = heading_idx + 1
        while i < len(doc.paragraphs):
            p = doc.paragraphs[i]
            # Stop when next heading starts
            if p.style and p.style.name.startswith('Heading'):
                break
            # Remove paragraph element
            p._element.getparent().remove(p._element)
            # Do not increment i because current index now refers to next paragraph
        
    
    def _insert_description(self, doc: Document, start_idx: int, description: str):
        """Insert description text after a heading"""
        # Create a new paragraph right after the heading with the description
        heading_para = doc.paragraphs[start_idx - 1]
        new_para = heading_para.insert_paragraph_after(description)
        new_para.style = 'Normal'
    
    def _insert_bullet_list(self, doc: Document, start_idx: int, items: List[str]):
        """Insert a bullet list after a heading"""
        # Insert bullet list items right after the heading
        heading_para = doc.paragraphs[start_idx - 1]
        insert_after = heading_para
        for item in items:
            insert_after = insert_after.insert_paragraph_after(item)
            insert_after.style = 'List Bullet'
    
    def cleanup_old_files(self, days: int = 7):
        """Remove generated documents older than specified days"""
        import time
        current_time = time.time()
        day_seconds = 86400 * days
        
        for file_path in self.output_dir.glob("*"):
            if file_path.is_file():
                file_age = current_time - file_path.stat().st_mtime
                if file_age > day_seconds:
                    file_path.unlink()


# Global instance
document_generator = DocumentGenerator()

