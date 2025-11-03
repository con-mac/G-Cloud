FROM public.ecr.aws/lambda/python:3.10

# Install LibreOffice and dependencies
# Lambda base image uses Amazon Linux 2023
# Use python-docx to extract content and generate PDF via reportlab
# This avoids needing LibreOffice in Lambda

# Copy requirements and install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY pdf_converter.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "pdf_converter.handler" ]

