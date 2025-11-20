import json

import pytest

from pdf_converter import pdf_converter


def test_pdf_handler_requires_word_key(monkeypatch):
    monkeypatch.setenv("OUTPUT_BUCKET_NAME", "dummy")
    result = pdf_converter.handler({}, None)
    assert result["success"] is False
    assert result["error_type"] == "ValueError"
    assert "word_s3_key" in result["error"]


def test_pdf_handler_parses_string_event(monkeypatch):
    monkeypatch.setenv("OUTPUT_BUCKET_NAME", "dummy")
    event = json.dumps({"word_s3_key": "generated/test.docx", "word_bucket": "dummy"})
    # Patch boto3 client to avoid AWS calls
    class FakeClient:
        def download_file(self, *args, **kwargs):
            raise FileNotFoundError("skip actual download")

    monkeypatch.setattr(pdf_converter, "s3_client", FakeClient())
    result = pdf_converter.handler(event, None)
    assert result["success"] is False
    assert result["error_type"] in {"FileNotFoundError", "RuntimeError"}

