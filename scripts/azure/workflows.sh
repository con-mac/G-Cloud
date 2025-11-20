#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOWS_DIR="${ROOT_DIR}/.github/workflows"
ENV_DIR="${ROOT_DIR}/infrastructure/azure/environments"

log() {
  printf '\n[azure-workflows] %s\n' "$1"
}

log "Ensuring directories exist"
mkdir -p "${WORKFLOWS_DIR}" "${ENV_DIR}"

TARGET="${ENV_DIR}/prod.tfvars"
if [[ -f "$TARGET" ]]; then
  log "Updating ${TARGET#${ROOT_DIR}/}"
else
  log "Creating ${TARGET#${ROOT_DIR}/}"
fi
cat <<'EOF' > "$TARGET"
environment            = "prod"
location               = "uksouth"
resource_group_name    = "gcloud-prod-rg"
resource_naming_prefix = "gcloud"
backend_resource_group  = "gcloud-tfstate-rg"
backend_storage_account = "gcloudtfstateprod"
backend_container_name  = "tfstate"
tags = {
  owner       = "Platform"
  costCentre  = "G-Cloud"
  environment = "prod"
}
EOF

TARGET="${WORKFLOWS_DIR}/security-and-tests.yml"
if [[ -f "$TARGET" ]]; then
  log "Updating ${TARGET#${ROOT_DIR}/}"
else
  log "Creating ${TARGET#${ROOT_DIR}/}"
fi
cat <<'EOF' > "$TARGET"
name: Security and Tests

on:
  pull_request:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  lint-and-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'

      - name: Install Python dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r backend/requirements.txt pytest pip-audit bandit

      - name: Run unit tests
        run: pytest backend/tests

      - name: pip-audit
        run: pip-audit -r backend/requirements.txt --progress-spinner off

      - name: Bandit security scan
        run: bandit -r backend/app backend/sharepoint_service

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install frontend dependencies
        run: npm ci
        working-directory: frontend

      - name: Frontend lint
        run: npm run lint
        working-directory: frontend

      - name: Frontend build smoke test
        run: npm run build
        working-directory: frontend

      - name: npm audit (high severity and above)
        run: npm audit --audit-level=high || true
        working-directory: frontend
EOF

TARGET="${WORKFLOWS_DIR}/deploy-prod.yml"
if [[ -f "$TARGET" ]]; then
  log "Updating ${TARGET#${ROOT_DIR}/}"
else
  log "Creating ${TARGET#${ROOT_DIR}/}"
fi
cat <<'EOF' > "$TARGET"
name: Deploy Prod

on:
  push:
    branches:
      - main
  workflow_dispatch:

concurrency:
  group: prod-deploy
  cancel-in-progress: false

env:
  TF_CLI_ARGS_plan: -lock-timeout=5m
  TF_CLI_ARGS_apply: -lock-timeout=5m -auto-approve

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - name: Install Python deps
        run: |
          python -m pip install --upgrade pip
          pip install -r backend/requirements.txt pytest
      - name: Run pytest
        run: pytest backend/tests
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      - name: Install frontend deps
        run: npm ci
        working-directory: frontend
      - name: Frontend build
        run: npm run build
        working-directory: frontend

  terraform-deploy:
    runs-on: ubuntu-latest
    needs: quality-gate
    permissions:
      id-token: write
      contents: read
    env:
      ARM_USE_OIDC: 'true'
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      TF_VAR_backend_resource_group: ${{ vars.TF_BACKEND_RESOURCE_GROUP }}
      TF_VAR_backend_storage_account: ${{ vars.TF_BACKEND_STORAGE_ACCOUNT }}
      TF_VAR_backend_container_name: ${{ vars.TF_BACKEND_CONTAINER_NAME }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.5

      - name: Terraform init
        working-directory: infrastructure/azure
        run: |
          terraform init \
            -backend-config="resource_group_name=${{ vars.TF_BACKEND_RESOURCE_GROUP }}" \
            -backend-config="storage_account_name=${{ vars.TF_BACKEND_STORAGE_ACCOUNT }}" \
            -backend-config="container_name=${{ vars.TF_BACKEND_CONTAINER_NAME }}"

      - name: Terraform plan
        working-directory: infrastructure/azure
        run: terraform plan -var-file=environments/prod.tfvars

      - name: Terraform apply
        if: github.ref == 'refs/heads/main'
        working-directory: infrastructure/azure
        run: terraform apply -var-file=environments/prod.tfvars

      - name: Capture Terraform outputs
        id: tf-out
        working-directory: infrastructure/azure
        run: terraform output -json > $GITHUB_OUTPUT

      - name: Build backend package (placeholder)
        run: |
          echo "TODO: package backend for Azure Function deployment"

      - name: Deploy API Function App (placeholder)
        run: |
          echo "TODO: deploy API function app using az functionapp deployment"

      - name: Deploy PDF Function App (placeholder)
        run: |
          echo "TODO: deploy PDF converter image via ACR/Function App"

      - name: Deploy frontend (placeholder)
        run: |
          echo "TODO: upload frontend build to Static Web App"
EOF

log "Workflow scaffolding complete. Review files in .github/workflows/."
