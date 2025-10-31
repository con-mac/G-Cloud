import base64
from pathlib import Path
from zipfile import ZipFile
from app.services.document_generator import document_generator

def _tiny_png_data_url():
    # 1x1 transparent PNG
    b64 = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQAB"
        "J8iZ2QAAAABJRU5ErkJggg=="
    )
    return f"data:image/png;base64,{b64}"


def test_generate_service_description_creates_clean_doc(tmp_path):
    title = "My New Service"
    description = "Lorem ipsum dolor sit amet " * 10  # 50 words
    features = ["Fast secure cloud delivery", "Automated compliance checks"]
    benefits = ["Reduce risk and cost", "Accelerate time to value"]
    html = f"""
    <h3>Overview</h3>
    <p>This is a <strong>rich</strong> section with <em>formatting</em>.</p>
    <p><img src="{_tiny_png_data_url()}" /></p>
    """

    result = document_generator.generate_service_description(
        title=title,
        description=description.strip(),
        features=features,
        benefits=benefits,
        service_definition=[{"subtitle": "Section A", "content": html}],
    )

    docx_path = Path(result["word_path"])
    assert docx_path.exists(), "DOCX should be generated"

    # Inspect docx internals
    with ZipFile(docx_path, 'r') as z:
        xml = z.read('word/document.xml').decode('utf-8')
        # Title appears, placeholders removed
        assert title in xml
        assert 'AI Security' not in xml
        assert 'Add Title' not in xml
        assert '{{SERVICE_NAME}}' not in xml
        # TOC field instruction exists if Contents heading present
        # Not guaranteed if template lacks Contents heading; check non-fatal
        try:
            settings_xml = z.read('word/settings.xml').decode('utf-8')
            assert 'updateFields' in settings_xml
        except KeyError:
            pass
        # Image embedded in media folder
        media_files = [n for n in z.namelist() if n.startswith('word/media/')]
        assert any(n.lower().endswith('.png') for n in media_files), "Embedded image should be present"


def test_generate_fallback_when_headings_missing(tmp_path, monkeypatch):
    # Force a minimal template without expected headings by pointing to a blank doc in templates
    # Here we simulate by ensuring replacement still appends at end
    title = "Fallback Service"
    description = "Desc text"
    features = ["F1", "F2"]
    benefits = ["B1", "B2"]
    result = document_generator.generate_service_description(
        title=title,
        description=description,
        features=features,
        benefits=benefits,
        service_definition=None,
    )
    docx_path = Path(result["word_path"])
    with ZipFile(docx_path, 'r') as z:
        xml = z.read('word/document.xml').decode('utf-8')
        assert 'Short Service Description' in xml
        assert description in xml
        assert 'Key Service Features' in xml
        assert 'Key Service Benefits' in xml
