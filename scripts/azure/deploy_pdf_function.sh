#!/usr/bin/env bash
set -euo pipefail

# Configures the pdf converter function app to pull the latest container from ACR.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTION_APP="${FUNCTION_APP_NAME:-gcloud-pdf-prod}"
RESOURCE_GROUP="${RESOURCE_GROUP:-gcloud-prod-rg}"
REGISTRY_NAME="${ACR_NAME:-gcloudacrprodun8d8}"
IMAGE_NAME="${IMAGE_NAME:-pdf-converter}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY_LOGIN_SERVER="${REGISTRY_NAME}.azurecr.io"
IMAGE_REF="${REGISTRY_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

log() {
  printf '\n[deploy-pdf] %s\n' "$*"
}

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required" >&2
  exit 1
fi

log "Ensuring Function App identity has AcrPull on ${REGISTRY_LOGIN_SERVER}"
FUNCTION_IDENTITY=$(az functionapp identity show \
  --name "${FUNCTION_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query principalId -o tsv)

if [[ -z "${FUNCTION_IDENTITY}" ]]; then
  echo "Failed to resolve function app identity" >&2
  exit 1
fi

ACR_ID=$(az acr show --name "${REGISTRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)

if ! az role assignment list --assignee "${FUNCTION_IDENTITY}" --scope "${ACR_ID}" --query "[?roleDefinitionName=='AcrPull']" -o tsv | grep -q .; then
  log "Assigning AcrPull"
  az role assignment create \
    --assignee "${FUNCTION_IDENTITY}" \
    --role AcrPull \
    --scope "${ACR_ID}" >/dev/null
fi

log "Updating function app container configuration"
az functionapp config container set \
  --name "${FUNCTION_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --docker-custom-image-name "${IMAGE_REF}" \
  --docker-registry-server-url "https://${REGISTRY_LOGIN_SERVER}"

log "Forcing site restart"
az functionapp restart --name "${FUNCTION_APP}" --resource-group "${RESOURCE_GROUP}" >/dev/null

log "Container deployment complete"
