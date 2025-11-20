#!/usr/bin/env bash
set -euo pipefail

# Builds the Vite frontend and uploads it to the Azure Static Web App.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="${ROOT_DIR}/frontend"
DIST_DIR="${FRONTEND_DIR}/dist"
STATIC_APP="${STATIC_APP_NAME:-gcloud-frontend}"
RESOURCE_GROUP="${RESOURCE_GROUP:-gcloud-prod-rg}"
API_BASE_URL="${VITE_API_BASE_URL:-https://gcloud-api-prod.azurewebsites.net}"

log() {
  printf '\n[deploy-frontend] %s\n' "$*"
}

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required" >&2
  exit 1
fi

# Ensure the staticwebapp extension is available (upload command lives there)
if ! az extension show --name staticwebapp >/dev/null 2>&1; then
  log "Installing az staticwebapp extension"
  az extension add --name staticwebapp >/dev/null
fi

log "Installing npm dependencies"
(
  cd "${FRONTEND_DIR}"
  npm ci
)

log "Building Vite bundle with API base ${API_BASE_URL}"
(
  cd "${FRONTEND_DIR}"
  VITE_API_BASE_URL="${API_BASE_URL}" npm run build
)

log "Retrieving deployment token"
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "${STATIC_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query properties.apiKey -o tsv)

if [[ -z "${DEPLOY_TOKEN}" ]]; then
  echo "Failed to retrieve deployment token" >&2
  exit 1
fi

log "Deploying static assets via swa cli"
npx @azure/static-web-apps-cli@1.1.10 deploy "${DIST_DIR}" \
  --app-name "${STATIC_APP}" \
  --resource-group "${RESOURCE_GROUP}" \
  --deployment-token "${DEPLOY_TOKEN}" \
  --env production \
  --verbose

log "Frontend deployment complete"
