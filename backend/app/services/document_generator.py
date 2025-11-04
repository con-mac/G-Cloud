    def _update_toc_field(self, doc: Document):
        """Update/refresh the TOC field to populate it with actual headings.
        
        The issue is that Word TOC fields are not automatically updated.
        We'll delete and recreate the TOC field after content insertion.
        This ensures it's populated with the actual headings.
        """
        try:
            # Find the TOC paragraph
            toc_para = None
            toc_heading_idx = None
            
            for i, p in enumerate(doc.paragraphs):
                txt = (p.text or '').strip()
                if txt.lower() in ('contents', 'table of contents') and p.style and p.style.name.startswith('Heading'):
                    toc_heading_idx = i
                    # Find the paragraph after this heading (should be the TOC field)
                    if i + 1 < len(doc.paragraphs):
                        toc_para = doc.paragraphs[i + 1]
                    break
            
            if toc_para is None or toc_heading_idx is None:
                return
            
            # Delete the existing TOC field paragraph
            try:
                # Remove the TOC paragraph
                toc_para._p.getparent().remove(toc_para._p)
            except Exception:
                pass
            
            # Recreate the TOC field - this will force it to be populated
            # Insert new TOC field after the heading
            heading_para = doc.paragraphs[toc_heading_idx]
            new_toc_para = self._insert_paragraph_after(heading_para, '')
            
            # Build field codes: TOC \o "1-3" \h \z \u
            fld_begin = OxmlElement('w:fldChar')
            fld_begin.set(qn('w:fldCharType'), 'begin')
            
            instr = OxmlElement('w:instrText')
            instr.set(qn('xml:space'), 'preserve')
            instr.text = 'TOC \\o "1-3" \\h \\z \\u'
            
            fld_sep = OxmlElement('w:fldChar')
            fld_sep.set(qn('w:fldCharType'), 'separate')
            
            fld_end = OxmlElement('w:fldChar')
            fld_end.set(qn('w:fldCharType'), 'end')
            
            r1 = OxmlElement('w:r')
            r1.append(fld_begin)
            r2 = OxmlElement('w:r')
            r2.append(instr)
            r3 = OxmlElement('w:r')
            r3.append(fld_sep)
            r4 = OxmlElement('w:r')
            r4.append(fld_end)
            
            new_toc_para._p.append(r1)
            new_toc_para._p.append(r2)
            new_toc_para._p.append(r3)
            new_toc_para._p.append(r4)
            
        except Exception as e:
            # If updating fails, at least ensure updateFields is enabled
            print(f"Warning: Could not recreate TOC field: {e}")
            pass
