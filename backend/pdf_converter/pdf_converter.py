"""
PDF Converter Lambda Function
Converts Word documents to PDF using LibreOffice headless
This preserves all formatting, images, colors, cover page, contents page, etc.
"""

import os
import json
import subprocess
import boto3
from pathlib import Path

s3_client = boto3.client('s3')

OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET_NAME')


def handler(event, context):
    """
    Lambda handler for PDF conversion using LibreOffice
    
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
        
        # Convert to PDF using LibreOffice headless
        # This preserves all formatting, images, colors, cover page, contents page, etc.
        pdf_filename = word_filename.replace('.docx', '.pdf')
        local_pdf_path = output_dir / pdf_filename
        
        # LibreOffice headless command
        # Try different paths for LibreOffice
        libreoffice_cmd = None
        possible_paths = [
            '/opt/libreoffice7.6/program/soffice',  # Shelf image location
            '/usr/bin/libreoffice7.6',
            '/usr/bin/libreoffice',
            '/usr/bin/soffice',
            'libreoffice7.6',
            'libreoffice',
            'soffice'
        ]
        
        for cmd_path in possible_paths:
            try:
                # Check if it's an absolute path
                if cmd_path.startswith('/'):
                    if os.path.exists(cmd_path) and os.access(cmd_path, os.X_OK):
                        libreoffice_cmd = cmd_path
                        break
                else:
                    # Use which for commands in PATH
                    result = subprocess.run(['which', cmd_path], capture_output=True, text=True, timeout=5)
                    if result.returncode == 0:
                        libreoffice_cmd = result.stdout.strip()
                        break
            except:
                continue
        
        if not libreoffice_cmd:
            raise RuntimeError(f"LibreOffice not found. Checked: {', '.join(possible_paths)}")
        
        # --headless: Run without GUI
        # --convert-to pdf: Convert to PDF format
        # --outdir: Output directory
        # --nofirststartwizard: Skip first start wizard
        # --nodefault: Don't use default settings
        cmd = [
            libreoffice_cmd,
            '--headless',
            '--nofirststartwizard',
            '--nodefault',
            '--convert-to', 'pdf',
            '--outdir', str(output_dir),
            str(local_word_path)
        ]
        
        # Set environment variables for LibreOffice
        env = os.environ.copy()
        env['HOME'] = '/tmp'
        env['USERPROFILE'] = '/tmp'
        # Disable Java (not needed for headless conversion)
        env['JAVA_HOME'] = ''
        env['SAL_USE_VCLPLUGIN'] = 'headless'
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,  # 2 minutes timeout
            env=env,
            cwd=str(input_dir)
        )
        
        if result.returncode != 0:
            error_msg = f"LibreOffice conversion failed: {result.stderr}"
            print(f"ERROR: {error_msg}")
            print(f"STDOUT: {result.stdout}")
            raise RuntimeError(error_msg)
        
        # LibreOffice outputs PDF with same name but .pdf extension
        # Check if PDF was created
        expected_pdf = output_dir / pdf_filename
        if not expected_pdf.exists():
            # Sometimes LibreOffice creates PDF with different casing or naming
            # Try to find any PDF file in output directory
            pdf_files = list(output_dir.glob('*.pdf'))
            if pdf_files:
                expected_pdf = pdf_files[0]
            else:
                raise FileNotFoundError(f"PDF not generated: {expected_pdf}")
        
        # Upload PDF to S3
        pdf_s3_key = word_s3_key.replace('.docx', '.pdf')
        s3_client.upload_file(
            str(expected_pdf),
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
        expected_pdf.unlink(missing_ok=True)
        
        return {
            'success': True,
            'pdf_s3_key': pdf_s3_key,
            'pdf_url': presigned_url
        }
        
    except Exception as e:
        import traceback
        error_details = {
            'success': False,
            'error': str(e),
            'error_type': type(e).__name__,
            'traceback': traceback.format_exc()
        }
        print(f"PDF conversion error: {json.dumps(error_details)}")
        return error_details
