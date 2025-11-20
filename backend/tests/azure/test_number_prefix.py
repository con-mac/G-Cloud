import pytest

from sharepoint_service.document_parser import strip_number_prefix


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("1. Feature one", "Feature one"),
        ("  2) Benefit two", "Benefit two"),  # includes nbsp
        ("03 )Thin-space benefit", "Thin-space benefit"),
        ("No numbering", "No numbering"),
    ],
)
def test_strip_number_prefix_handles_mixed_whitespace(raw: str, expected: str) -> None:
    """Ensure numbering is removed consistently for Azure + SharePoint parity."""
    assert strip_number_prefix(raw) == expected

