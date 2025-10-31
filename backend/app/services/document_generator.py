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
from bs4 import BeautifulSoup
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


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
        benefits: List[str],
        service_definition: List[dict] | None = None
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
        # Insert service definition blocks if provided
        if service_definition:
            self._insert_service_definition(doc, service_definition)
        
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
        new_para = self._insert_paragraph_after(heading_para, description, 'Normal')
    
    def _insert_bullet_list(self, doc: Document, start_idx: int, items: List[str]):
        """Insert a bullet list after a heading"""
        # Insert bullet list items right after the heading
        heading_para = doc.paragraphs[start_idx - 1]
        insert_after = heading_para
        for item in items:
            insert_after = self._insert_paragraph_after(insert_after, item, 'List Bullet')

    def _insert_service_definition(self, doc: Document, blocks: List[dict]):
        """Insert Service Definition content: subsections with optional images and tables.

        Expected block format examples:
        {"subtitle": "AI Security advisory", "content": "Paragraph text...", "images": ["http://..."], "table": [["H1","H2"],["R1C1","R1C2"]] }
        """
        # Find the 'Service Definition' heading
        heading_idx = None
        for i, p in enumerate(doc.paragraphs):
            if p.text.strip() == 'Service Definition' or (
                p.style and p.style.name.startswith('Heading') and 'Service Definition' in p.text
            ):
                heading_idx = i
                break
        if heading_idx is None:
            return
        # Clear existing content under the heading
        self._clear_section_after_heading(doc, heading_idx)

        insert_after = doc.paragraphs[heading_idx]

        # Utilities for images
        def _add_image(after_para, url: str):
            try:
                import requests
                from io import BytesIO
                img_data = requests.get(url, timeout=10).content
                # Insert a new paragraph and add picture to the run
                p = self._insert_paragraph_after(after_para, '')
                run = p.add_run()
                run.add_picture(BytesIO(img_data))
                return p
            except Exception:
                # Ignore image failures silently
                return after_para

        # Build content
        for block in blocks:
            subtitle = block.get('subtitle')
            content_html = block.get('content')
            images = block.get('images', []) or []
            table = block.get('table')

            if subtitle:
                insert_after = self._insert_paragraph_after(insert_after, subtitle, 'Heading 3')

            if content_html:
                # Render limited HTML into docx
                insert_after = self._insert_html(doc, insert_after, content_html)

            for img_url in images:
                insert_after = _add_image(insert_after, img_url)

            if table and isinstance(table, list) and table:
                # Insert table after current insert_after by using document-level add and moving near
                rows = len(table)
                cols = max(len(r) for r in table if isinstance(r, list))
                t = doc.add_table(rows=rows, cols=cols)
                t.style = 'Table Grid'
                for r_idx, row in enumerate(table):
                    for c_idx, cell_text in enumerate(row):
                        t.cell(r_idx, c_idx).text = str(cell_text)
                # Add a blank paragraph after table to maintain spacing
                insert_after = self._insert_paragraph_after(insert_after, '')

    def _insert_html(self, doc: Document, after_para, html: str):
        """Very basic HTML renderer supporting <p>, <strong>, <em>, <ul>/<ol>/<li>, <h3>, <br>, <a>.
        Images are expected as separate 'images' array and handled elsewhere.
        Returns the last paragraph inserted for chaining.
        """
        soup = BeautifulSoup(html, 'html.parser')

        def render_inline(run, node):
            if node.name == 'strong' or node.name == 'b':
                r = run.add_text(node.get_text())
                run.bold = True
                return
            if node.name == 'em' or node.name == 'i':
                r = run.add_text(node.get_text())
                run.italic = True
                return
            if node.name == 'br':
                run.add_break()
                return
            # Default text
            run.add_text(node if isinstance(node, str) else node.get_text())

        def add_paragraph_with_inlines(text_or_node, style_name=None):
            p = self._insert_paragraph_after(after_para, '')
            if style_name:
                p.style = style_name
            if isinstance(text_or_node, str):
                p.add_run(text_or_node)
            else:
                for child in text_or_node.children:
                    if isinstance(child, str):
                        p.add_run(child)
                    else:
                        if child.name in ['strong','b','em','i','br']:
                            render_inline(p.add_run(''), child)
                        elif child.name == 'img':
                            src = child.get('src')
                            if src:
                                # Insert image as separate paragraph after current
                                p_img = self._insert_paragraph_after(p, '')
                                try:
                                    import requests
                                    from io import BytesIO
                                    img_bytes = requests.get(src, timeout=10).content
                                    run = p_img.add_run()
                                    run.add_picture(BytesIO(img_bytes))
                                    p = p_img
                                except Exception:
                                    # If image fetch fails, fall back to a link
                                    p_img.add_run(f"[image: {src}]")
                                    p = p_img
                        else:
                            p.add_run(child.get_text())
            return p

        last = after_para
        for el in soup.contents:
            if isinstance(el, str) and el.strip():
                last = add_paragraph_with_inlines(el, None)
            elif getattr(el, 'name', None):
                name = el.name.lower()
                if name == 'h3':
                    last = add_paragraph_with_inlines(el, 'Heading 3')
                elif name == 'p':
                    last = add_paragraph_with_inlines(el, 'Normal')
                elif name in ['ul','ol']:
                    for li in el.find_all('li', recursive=False):
                        p_li = self._insert_paragraph_after(last, li.get_text(), 'List Bullet' if name=='ul' else 'List Number')
                        last = p_li
                elif name == 'br':
                    last = self._insert_paragraph_after(last, '')
                else:
                    # Fallback as paragraph
                    last = add_paragraph_with_inlines(el, 'Normal')
        return last

    def _insert_paragraph_after(self, paragraph: Paragraph, text: str = '', style_name: str | None = None) -> Paragraph:
        """Insert a new paragraph directly after the given paragraph using low-level XML ops."""
        # Create a new paragraph element and insert after current
        new_p = OxmlElement('w:p')
        paragraph._p.addnext(new_p)
        new_para = Paragraph(new_p, paragraph._parent)
        if text:
            new_para.add_run(text)
        if style_name:
            new_para.style = style_name
        return new_para
    
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

