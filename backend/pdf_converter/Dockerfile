# Multi-stage build to get LibreOffice working in Lambda
# Stage 1: Build LibreOffice on Fedora (has LibreOffice in default repos)
FROM fedora:38 as builder

# Install LibreOffice
RUN dnf install -y \
    libreoffice \
    libreoffice-writer \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Stage 2: Lambda runtime with LibreOffice
FROM public.ecr.aws/lambda/python:3.10

# Copy LibreOffice binaries and libraries from Fedora
# On Fedora, LibreOffice is in /usr/lib64
COPY --from=builder /usr/lib64/libreoffice /usr/lib64/libreoffice
COPY --from=builder /usr/bin/libreoffice /usr/bin/libreoffice
COPY --from=builder /usr/bin/soffice /usr/bin/soffice

# Copy essential shared libraries (create directories first)
RUN mkdir -p /opt/lib64

# Copy libraries from lib64 (Fedora uses lib64, not lib)
COPY --from=builder /usr/lib64/ /opt/lib64/

# Set library path
ENV LD_LIBRARY_PATH=/opt/lib64:/usr/lib64:${LD_LIBRARY_PATH}
ENV PATH=/usr/bin:${PATH}
ENV HOME=/tmp

# Copy Python requirements and install
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN python -m pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY pdf_converter.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "pdf_converter.handler" ]
