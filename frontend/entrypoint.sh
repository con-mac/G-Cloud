#!/bin/sh
# Entrypoint script to inject runtime environment variables into the React app

# Read environment variables from Azure App Service
CLIENT_ID="${VITE_AZURE_AD_CLIENT_ID:-}"
TENANT_ID="${VITE_AZURE_AD_TENANT_ID:-}"
REDIRECT_URI="${VITE_AZURE_AD_REDIRECT_URI:-}"
ADMIN_GROUP_ID="${VITE_AZURE_AD_ADMIN_GROUP_ID:-}"

# Escape single quotes in values for JavaScript
escape_js() {
  echo "$1" | sed "s/'/\\\'/g"
}

CLIENT_ID_ESC=$(escape_js "$CLIENT_ID")
TENANT_ID_ESC=$(escape_js "$TENANT_ID")
REDIRECT_URI_ESC=$(escape_js "$REDIRECT_URI")
ADMIN_GROUP_ID_ESC=$(escape_js "$ADMIN_GROUP_ID")

# Create JavaScript config object (must be injected before </head>)
CONFIG_JS="window.__ENV__ = {
  VITE_AZURE_AD_CLIENT_ID: '${CLIENT_ID_ESC}',
  VITE_AZURE_AD_TENANT_ID: '${TENANT_ID_ESC}',
  VITE_AZURE_AD_REDIRECT_URI: '${REDIRECT_URI_ESC}',
  VITE_AZURE_AD_ADMIN_GROUP_ID: '${ADMIN_GROUP_ID_ESC}'
};"

# Inject config into index.html before </head> tag
# Use a more robust sed pattern that handles the closing tag
sed -i "s|</head>|<script>${CONFIG_JS}</script></head>|" /usr/share/nginx/html/index.html

# Verify injection worked
if grep -q "window.__ENV__" /usr/share/nginx/html/index.html; then
  echo "✓ Environment variables injected successfully"
else
  echo "✗ WARNING: Failed to inject environment variables"
fi

# Start nginx
exec nginx -g 'daemon off;'

