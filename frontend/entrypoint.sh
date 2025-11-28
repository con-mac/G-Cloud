#!/bin/sh
# Entrypoint script to inject runtime environment variables into the React app

# Read environment variables from Azure App Service
CLIENT_ID="${VITE_AZURE_AD_CLIENT_ID:-}"
TENANT_ID="${VITE_AZURE_AD_TENANT_ID:-}"
REDIRECT_URI="${VITE_AZURE_AD_REDIRECT_URI:-}"
ADMIN_GROUP_ID="${VITE_AZURE_AD_ADMIN_GROUP_ID:-}"

# Create JavaScript config object
CONFIG_JS="window.__ENV__ = {
  VITE_AZURE_AD_CLIENT_ID: '${CLIENT_ID}',
  VITE_AZURE_AD_TENANT_ID: '${TENANT_ID}',
  VITE_AZURE_AD_REDIRECT_URI: '${REDIRECT_URI}',
  VITE_AZURE_AD_ADMIN_GROUP_ID: '${ADMIN_GROUP_ID}'
};"

# Inject config into index.html before </head>
sed -i "s|</head>|<script>${CONFIG_JS}</script></head>|" /usr/share/nginx/html/index.html

# Start nginx
exec nginx -g 'daemon off;'

