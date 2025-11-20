from app.azure.storage_paths import build_service_blob_key


def test_build_service_blob_key_final_document() -> None:
    key = build_service_blob_key(
        service_name="Python Dev",
        doc_type="SERVICE DESC",
        gcloud_version="15",
        lot="3",
        extension="pdf",
    )
    assert key == (
        "GCloud 15/PA Services/Cloud Support Services LOT 3/"
        "Python_Dev/PA GC15 SERVICE DESC Python Dev.pdf"
    )


def test_build_service_blob_key_draft_document() -> None:
    key = build_service_blob_key(
        service_name="Edge AI Accelerator",
        doc_type="Pricing Doc",
        gcloud_version="14",
        lot="2",
        extension="docx",
        draft=True,
    )
    assert key.endswith("PA GC14 Pricing Doc Edge AI Accelerator_draft.docx")
    assert key.startswith("GCloud 14/PA Services/Cloud Support Services LOT 2/")

