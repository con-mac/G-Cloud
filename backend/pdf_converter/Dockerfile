# Use pre-built LibreOffice base image from Shelf
# This image has LibreOffice 7.6 pre-installed and configured for Lambda
# The shelf image is based on Amazon Linux 2023 (uses dnf, not yum)
FROM public.ecr.aws/shelf/lambda-libreoffice-base:7.6-node20-x86_64

# Python 3 is already installed in the shelf image (we verified it)
# Just install pip if needed
RUN python3 -m ensurepip --upgrade || \
    dnf install -y python3-pip && \
    dnf clean all || \
    true

# Create symlinks for libreoffice (it's at /usr/bin/libreoffice7.6)
RUN ln -sf /usr/bin/libreoffice7.6 /usr/bin/libreoffice && \
    ln -sf /usr/bin/libreoffice7.6 /usr/bin/soffice

# Verify LibreOffice is accessible
RUN /usr/bin/libreoffice7.6 --version || echo "LibreOffice version check"

# Set up Python environment
ENV PYTHONUNBUFFERED=1
ENV HOME=/tmp
ENV PATH=/usr/bin:${PATH}

# Copy Python requirements and install
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN python3 -m pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy function code
COPY pdf_converter.py ${LAMBDA_TASK_ROOT}/

# Create Lambda handler wrapper
# Lambda expects handler in format "module.function"
RUN echo 'import sys; sys.path.insert(0, "/var/task"); from pdf_converter import handler as pdf_handler; \
def lambda_handler(event, context): \
    return pdf_handler(event, context)' > ${LAMBDA_TASK_ROOT}/lambda_handler.py

# Set the CMD - Lambda will call lambda_handler.lambda_handler
CMD ["python3", "/var/task/lambda_handler.py"]
