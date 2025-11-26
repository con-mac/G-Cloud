# Deploy Frontend Script (PowerShell)
# Deploys React frontend to Static Web App or App Service

$ErrorActionPreference = "Stop"

# Load configuration
if (-not (Test-Path "config\deployment-config.env")) {
    Write-Error "deployment-config.env not found. Please run deploy.ps1 first."
    exit 1
}

# Parse environment file
$config = @{}
Get-Content "config\deployment-config.env" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $config[$matches[1]] = $matches[2]
    }
}

$WEB_APP_NAME = $config.WEB_APP_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Deploying frontend to Web App..."

# Check if frontend directory exists
if (-not (Test-Path "frontend")) {
    Write-Warning "Frontend directory not found. Creating structure..."
    New-Item -ItemType Directory -Path "frontend" | Out-Null
}

Push-Location frontend

# Build frontend
Write-Info "Building frontend..."

# Create essential config files if they don't exist
if (-not (Test-Path "package.json")) {
    Write-Info "Creating essential frontend config files..."
    
    # Create package.json
    $packageJson = @{
        name = "gcloud-automation-frontend"
        version = "1.0.0"
        description = "G-Cloud Proposal Automation System - Frontend"
        type = "module"
        scripts = @{
            dev = "vite"
            build = "tsc && vite build"
            preview = "vite preview"
        }
        dependencies = @{
            "@azure/msal-browser" = "^3.5.0"
            "@azure/msal-react" = "^2.0.7"
            "@emotion/react" = "^11.11.1"
            "@emotion/styled" = "^11.11.0"
            "@hookform/resolvers" = "^3.3.2"
            "@mui/icons-material" = "^5.14.19"
            "@mui/material" = "^5.14.19"
            "@tanstack/react-query" = "^5.12.0"
            "@types/lodash" = "^4.17.20"
            "axios" = "^1.6.2"
            "date-fns" = "^2.30.0"
            "dompurify" = "^3.0.6"
            "draft-js" = "^0.11.7"
            "lodash" = "^4.17.21"
            "quill-image-resize" = "^3.0.9"
            "quill-image-resize-module-react" = "^3.0.0"
            "quill-table" = "^1.0.0"
            "react" = "^18.2.0"
            "react-dom" = "^18.2.0"
            "react-hook-form" = "^7.48.2"
            "react-quill" = "^2.0.0"
            "react-router-dom" = "^6.20.0"
            "react-toastify" = "^9.1.3"
            "recharts" = "^3.4.1"
            "zod" = "^3.22.4"
            "zustand" = "^4.4.7"
        }
        devDependencies = @{
            "@types/react" = "^18.2.43"
            "@types/react-dom" = "^18.2.17"
            "@typescript-eslint/eslint-plugin" = "^6.13.2"
            "@typescript-eslint/parser" = "^6.13.2"
            "@vitejs/plugin-react" = "^4.2.1"
            "eslint" = "^8.55.0"
            "eslint-config-prettier" = "^9.1.0"
            "eslint-plugin-react" = "^7.33.2"
            "eslint-plugin-react-hooks" = "^4.6.0"
            "eslint-plugin-react-refresh" = "^0.4.5"
            "prettier" = "^3.1.0"
            "typescript" = "^5.3.3"
            "vite" = "^5.0.6"
        }
    }
    $packageJson | ConvertTo-Json -Depth 10 | Out-File -FilePath "package.json" -Encoding utf8
    
    # Create vite.config.ts
    $viteConfig = @"
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@/components': path.resolve(__dirname, './src/components'),
      '@/pages': path.resolve(__dirname, './src/pages'),
      '@/hooks': path.resolve(__dirname, './src/hooks'),
      '@/services': path.resolve(__dirname, './src/services'),
      '@/store': path.resolve(__dirname, './src/store'),
      '@/types': path.resolve(__dirname, './src/types'),
      '@/utils': path.resolve(__dirname, './src/utils'),
      '@/styles': path.resolve(__dirname, './src/styles'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
"@
    $viteConfig | Out-File -FilePath "vite.config.ts" -Encoding utf8
    
    # Create index.html
    $indexHtml = @"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="G-Cloud Proposal Automation System - PA Consulting" />
    <meta name="theme-color" content="#003DA5" />
    <title>G-Cloud Automation System</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
"@
    $indexHtml | Out-File -FilePath "index.html" -Encoding utf8
    
    # Create tsconfig.json
    $tsconfig = @"
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@/components/*": ["src/components/*"],
      "@/pages/*": ["src/pages/*"],
      "@/hooks/*": ["src/hooks/*"],
      "@/services/*": ["src/services/*"],
      "@/store/*": ["src/store/*"],
      "@/types/*": ["src/types/*"],
      "@/utils/*": ["src/utils/*"],
      "@/styles/*": ["src/styles/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
"@
    $tsconfig | Out-File -FilePath "tsconfig.json" -Encoding utf8
    
    # Create tsconfig.node.json
    $tsconfigNode = @"
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
"@
    $tsconfigNode | Out-File -FilePath "tsconfig.node.json" -Encoding utf8
    
    Write-Success "Essential config files created"
}

# Verify src folder exists
if (-not (Test-Path "src") -or -not (Test-Path "src\main.tsx")) {
    Write-Error "Frontend src folder or main.tsx not found. Please ensure frontend/src/ directory exists with your React source files."
    Pop-Location
    exit 1
}

npm install
npm run build

# Get Function App URL for API configuration
$FUNCTION_APP_URL = az functionapp show `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query defaultHostName -o tsv

# Create .env.production with API URL
# Note: For private endpoints, this will be the private DNS name
$envContent = @"
VITE_API_BASE_URL=https://${FUNCTION_APP_URL}/api/v1
VITE_AZURE_AD_TENANT_ID=PLACEHOLDER_TENANT_ID
VITE_AZURE_AD_CLIENT_ID=PLACEHOLDER_CLIENT_ID
VITE_AZURE_AD_REDIRECT_URI=https://${WEB_APP_NAME}.azurewebsites.net
"@

$envContent | Out-File -FilePath ".env.production" -Encoding utf8

# Rebuild with production env
npm run build

# Deploy to App Service
Write-Info "Deploying to Web App: $WEB_APP_NAME"

# Check if frontend dist exists
if (-not (Test-Path "dist") -or (Get-ChildItem "dist" -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
    Write-Warning "Frontend dist folder not found or empty. Skipping code deployment."
    Write-Warning "Build frontend first with: npm run build"
    Write-Info "Web App exists and will be configured, but code deployment skipped."
} else {
    # Create deployment package
    Push-Location dist
    Compress-Archive -Path * -DestinationPath ..\deployment.zip -Force
    Pop-Location
    
    # Deploy using zip deploy
    az webapp deployment source config-zip `
        --resource-group $RESOURCE_GROUP `
        --name $WEB_APP_NAME `
        --src deployment.zip | Out-Null
}

# Configure app settings (updates existing or creates new)
Write-Info "Configuring Web App settings..."

az webapp config appsettings set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings `
        "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false" `
        "SCM_DO_BUILD_DURING_DEPLOYMENT=false" `
    --output none | Out-Null

Write-Success "Frontend deployment complete!"
Write-Info "Note: Azure AD configuration needs to be updated with actual values"
Write-Info "Note: Private endpoint configuration may be required"

Pop-Location

