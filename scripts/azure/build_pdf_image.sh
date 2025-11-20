#!/usr/bin/env bash
set -euo pipefail

# Builds and pushes the PDF converter container image to Azure Container Registry.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PDF_DIR="${ROOT_DIR}/backend/pdf_converter"
REGISTRY="${ACR_NAME:-gcloudacrprodun8d8}.azurecr.io"
IMAGE_NAME="pdf-converter"
TAG="${IMAGE_TAG:-latest}"
IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:${TAG}"
RESOURCE_GROUP="${RESOURCE_GROUP:-gcloud-prod-rg}"

log() {
  printf '\n[pdf-image] %s\n' "$*"
}

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required" >&2
  exit 1
fi

log "Logging into ACR ${REGISTRY}"
az acr login --name "${REGISTRY%%.azurecr.io}" >/dev/null

log "Building image ${IMAGE_REF}"
docker build -t "${IMAGE_REF}" "${PDF_DIR}"

log "Pushing image ${IMAGE_REF}"
docker push "${IMAGE_REF}"

log "Image push complete"
