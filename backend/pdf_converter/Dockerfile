# Multi-stage build: Use Lambda Python base and copy LibreOffice from Shelf
# Stage 1: Get LibreOffice from shelf image
FROM public.ecr.aws/shelf/lambda-libreoffice-base:7.6-node20-x86_64 as libreoffice-source

# Stage 2: Lambda Python runtime with LibreOffice
FROM public.ecr.aws/lambda/python:3.10

# Install system libraries required by LibreOffice
# LibreOffice needs X11 libraries even in headless mode
RUN yum install -y \
    libXinerama \
    libXext \
    libXrender \
    libSM \
    libICE \
    libGL \
    cairo \
    cairo-gobject \
    pango \
    gtk3 \
    && yum clean all \
    && rm -rf /var/cache/yum

# Copy LibreOffice from /opt/libreoffice7.6 (this is where it's installed in shelf image)
COPY --from=libreoffice-source /opt/libreoffice7.6 /opt/libreoffice7.6

# Copy the symlink and create our own
COPY --from=libreoffice-source /usr/bin/libreoffice7.6 /usr/bin/libreoffice7.6

# Create symlinks
RUN ln -sf /opt/libreoffice7.6/program/soffice /usr/bin/libreoffice && \
    ln -sf /opt/libreoffice7.6/program/soffice /usr/bin/soffice && \
    ln -sf /opt/libreoffice7.6/program/soffice /usr/bin/libreoffice7.6

# Disable Java in LibreOffice (not needed for headless conversion)
ENV JAVA_HOME=""
ENV SAL_USE_VCLPLUGIN="headless"
ENV HOME=/tmp
ENV PATH=/opt/libreoffice7.6/program:/usr/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/libreoffice7.6/program:/usr/lib64:${LD_LIBRARY_PATH}

# Copy Python requirements and install
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN python3 -m pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Copy function code
COPY pdf_converter.py ${LAMBDA_TASK_ROOT}/

# Create Lambda handler
RUN printf 'import sys\n\
sys.path.insert(0, "/var/task")\n\
from pdf_converter import handler\n\
def lambda_handler(event, context):\n\
    return handler(event, context)\n' > ${LAMBDA_TASK_ROOT}/handler.py

# Lambda Python runtime expects handler.handler
CMD ["handler.lambda_handler"]
