#!/usr/bin/env bash
set -euo pipefail

# Packages the FastAPI backend and deploys it to the gcloud-api-prod Azure Function App.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
DIST_DIR="${ROOT_DIR}/build/api_function"
PYTHON_PACKAGE_DIR="${DIST_DIR}/.python_packages/lib/site-packages"
ZIP_PATH="${DIST_DIR}/function.zip"
FUNCTION_APP="${FUNCTION_APP_NAME:-gcloud-api-prod}"
RESOURCE_GROUP="${RESOURCE_GROUP:-gcloud-prod-rg}"
PYTHON_VERSION="${PYTHON_VERSION:-3.10}"

log() {
  printf '\n[deploy-api] %s\n' "$*"
}

cleanup() {
  if [ "${KEEP_BUILD:-0}" != "1" ]; then
    rm -rf "${DIST_DIR}"
  else
    log "KEEP_BUILD=1, leaving ${DIST_DIR} for inspection"
  fi
}

trap cleanup EXIT

log "Preparing build directory"
rm -rf "${DIST_DIR}"
mkdir -p "${PYTHON_PACKAGE_DIR}"

log "Installing dependencies to Azure Functions package directory"
pip install --target "${PYTHON_PACKAGE_DIR}" -r "${BACKEND_DIR}/requirements.txt"

log "Copying backend application files"
rsync -a \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'tests' \
  --exclude 'function_app' \
  --exclude 'host.json' \
  --exclude 'build' \
  "${BACKEND_DIR}/" "${DIST_DIR}/"

# Ensure mock_sharepoint data is included for environments without external storage
if [ -d "${ROOT_DIR}/mock_sharepoint" ]; then
  log "Including mock_sharepoint data in deployment package"
  rsync -a "${ROOT_DIR}/mock_sharepoint" "${DIST_DIR}/"
fi

# Include docs folder (contains questionnaire Excel file and templates)
if [ -d "${ROOT_DIR}/docs" ]; then
  log "Including docs folder in deployment package"
  mkdir -p "${DIST_DIR}/docs"
  rsync -a "${ROOT_DIR}/docs/" "${DIST_DIR}/docs/"
fi

log "Copying Azure Functions metadata"
cp -R "${BACKEND_DIR}/function_app" "${DIST_DIR}/function_app"
cp "${BACKEND_DIR}/host.json" "${DIST_DIR}/host.json"
cp "${BACKEND_DIR}/requirements.txt" "${DIST_DIR}/requirements.txt"

log "Creating zip package"
(
  cd "${DIST_DIR}"
  zip -r "${ZIP_PATH}" . >/dev/null
)

log "Deploying zip package to ${FUNCTION_APP}"
az functionapp deployment source config-zip \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${FUNCTION_APP}" \
  --src "${ZIP_PATH}"

log "Deployment complete"
