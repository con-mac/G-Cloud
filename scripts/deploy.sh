#!/usr/bin/env bash
set -euo pipefail

# --- configuration -----------------------------------------------------------
REGION="${AWS_REGION:-eu-west-2}"
LAMBDA_FUNCTION="${LAMBDA_FUNCTION:-gcloud-automation-dev-api}"
FRONTEND_BUCKET="${FRONTEND_BUCKET:-gcloud-automation-dev-frontend}"
DEPLOY_BUCKET="${DEPLOY_BUCKET:-gcloud-automation-dev-lambda-deploy}"
DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION:-E3HBBN6GG7DUV7}"
LAMBDA_ZIP_KEY="lambda.zip"   # key inside deploy bucket if fallback is needed
# API Gateway base URL for frontend build; default to known Dev API endpoint
API_BASE_URL="${VITE_API_BASE_URL:-${API_GATEWAY_URL:-https://jqms1xopz9.execute-api.eu-west-2.amazonaws.com}}"
# -----------------------------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
PACKAGE_DIR="${BACKEND_DIR}/package"
ZIP_PATH="${BACKEND_DIR}/lambda.zip"

log() { printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$*"; }

command -v zip >/dev/null 2>&1 || {
  echo "zip not installed. Run 'sudo apt-get install zip' first."; exit 1; }

log "Cleaning previous build artefacts"
rm -rf "${PACKAGE_DIR}" "${ZIP_PATH}"

log "Installing backend runtime dependencies"
pip install --no-cache-dir -r "${BACKEND_DIR}/requirements.txt" --target "${PACKAGE_DIR}"

log "Pruning caches and tests to shrink deployment artefact"
find "${PACKAGE_DIR}" -name "__pycache__" -type d -prune -exec rm -rf {} +
find "${PACKAGE_DIR}" -name "*.pyc" -delete
find "${PACKAGE_DIR}" -type d -path "*/tests*" -prune -exec rm -rf {} +
find "${PACKAGE_DIR}" -type d -path "*/test*" -prune -exec rm -rf {} +

log "Creating Lambda deployment archive"
(
  cd "${PACKAGE_DIR}"
  zip -r9 "${ZIP_PATH}" .
)
(
  cd "${BACKEND_DIR}"
  zip -g lambda.zip app -r sharepoint_service >/dev/null
)

log "Updating Lambda function ${LAMBDA_FUNCTION}"
if ! aws lambda update-function-code \
      --function-name "${LAMBDA_FUNCTION}" \
      --zip-file "fileb://${ZIP_PATH}" \
      --region "${REGION}" >/dev/null
then
  log "Inline update exceeded size limit. Uploading via S3 fallback."
  aws s3 cp "${ZIP_PATH}" "s3://${DEPLOY_BUCKET}/${LAMBDA_ZIP_KEY}"
  aws lambda update-function-code \
    --function-name "${LAMBDA_FUNCTION}" \
    --s3-bucket "${DEPLOY_BUCKET}" \
    --s3-key "${LAMBDA_ZIP_KEY}" \
    --region "${REGION}" >/dev/null
fi

log "Building frontend bundle"
(
  cd "${FRONTEND_DIR}"
  npm ci
  echo "Setting VITE_API_BASE_URL=${API_BASE_URL}"
  VITE_API_BASE_URL="${API_BASE_URL}" npm run build
)

log "Syncing frontend assets to s3://${FRONTEND_BUCKET}"
aws s3 sync "${FRONTEND_DIR}/dist/" "s3://${FRONTEND_BUCKET}/" --delete

log "Invalidating CloudFront distribution ${DISTRIBUTION_ID}"
aws cloudfront create-invalidation \
  --distribution-id "${DISTRIBUTION_ID}" \
  --paths "/*" >/dev/null

log "Deployment complete"

