#!/bin/sh
# Entrypoint script to inject runtime environment variables into the React app

set -e  # Exit on any error

INDEX_HTML="/usr/share/nginx/html/index.html"

# Check if index.html exists
if [ ! -f "$INDEX_HTML" ]; then
  echo "ERROR: index.html not found at $INDEX_HTML"
  echo "Contents of /usr/share/nginx/html:"
  ls -la /usr/share/nginx/html/ || true
  exit 1
fi

# Read environment variables from Azure App Service
CLIENT_ID="${VITE_AZURE_AD_CLIENT_ID:-}"
TENANT_ID="${VITE_AZURE_AD_TENANT_ID:-}"
REDIRECT_URI="${VITE_AZURE_AD_REDIRECT_URI:-}"
ADMIN_GROUP_ID="${VITE_AZURE_AD_ADMIN_GROUP_ID:-}"

echo "Injecting environment variables..."
echo "CLIENT_ID: ${CLIENT_ID:0:8}..."
echo "TENANT_ID: ${TENANT_ID:0:8}..."
echo "REDIRECT_URI: $REDIRECT_URI"

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
if sed -i "s|</head>|<script>${CONFIG_JS}</script></head>|" "$INDEX_HTML"; then
  echo "✓ Environment variables injected successfully"
else
  echo "✗ WARNING: Failed to inject environment variables with sed"
  # Try alternative method: append before </head>
  if grep -q "</head>" "$INDEX_HTML"; then
    sed -i "s|</head>|<script>${CONFIG_JS}</script></head>|" "$INDEX_HTML"
    echo "✓ Retry successful"
  else
    echo "✗ ERROR: Could not find </head> tag in index.html"
    exit 1
  fi
fi

# Verify injection worked
if grep -q "window.__ENV__" "$INDEX_HTML"; then
  echo "✓ Verified: window.__ENV__ found in index.html"
else
  echo "✗ WARNING: window.__ENV__ not found after injection"
fi

# Test nginx config
echo "Testing nginx configuration..."
nginx -t || {
  echo "ERROR: nginx configuration test failed"
  exit 1
}

# Start nginx
echo "Starting nginx..."
exec nginx -g 'daemon off;'

