# Deploy Frontend Static Files to Function App via Azure Portal

This guide shows you how to manually deploy your React frontend build files to a Function App's `static/` folder using the Azure Portal.

## Prerequisites

- Frontend built and ready (files in `frontend/dist/` directory)
- Function App already created in Azure Portal
- Access to Azure Portal with appropriate permissions

## Step-by-Step Instructions

### Step 1: Build Your Frontend (if not already done)

**On your local machine:**

```bash
cd frontend
npm install
npm run build
```

This creates the `dist/` folder with all static files (HTML, CSS, JS, assets).

### Step 2: Prepare Deployment Package

**On your local machine:**

1. **Create a temporary directory structure:**
   ```bash
   mkdir -p deploy-frontend/static
   ```

2. **Copy all files from `frontend/dist/` to `deploy-frontend/static/`:**
   ```bash
   # Linux/Mac
   cp -r frontend/dist/* deploy-frontend/static/
   
   # Windows PowerShell
   Copy-Item -Path frontend\dist\* -Destination deploy-frontend\static\ -Recurse
   ```

3. **Create a zip file:**
   ```bash
   # Linux/Mac
   cd deploy-frontend
   zip -r ../frontend-deploy.zip .
   cd ..
   
   # Windows PowerShell
   Compress-Archive -Path deploy-frontend\* -DestinationPath frontend-deploy.zip
   ```

### Step 3: Deploy via Azure Portal - Method 1: Advanced Tools (Kudu)

This is the most straightforward method using the Azure Portal:

1. **Navigate to your Function App** in Azure Portal
   - Go to **Azure Portal** → **Function Apps**
   - Click on your Function App (e.g., `pa-gcloud15-api`)

2. **Open Advanced Tools (Kudu)**
   - In the left menu, scroll down to **Development Tools**
   - Click **Advanced Tools (Kudu)**
   - Click **Go** (opens in new tab)

3. **Navigate to File System**
   - In Kudu, click **Debug console** → **CMD** (or **PowerShell**)
   - You'll see the file system explorer

4. **Create `static` folder**
   - Navigate to `site/wwwroot/` (this is the root of your Function App)
   - Click **+** button → **New folder**
   - Name it `static`
   - Click **OK**

5. **Upload files to static folder**
   - Click into the `static` folder
   - Click **+** button → **Upload**
   - Select all files from your `frontend/dist/` directory
   - Or drag and drop files
   - Wait for upload to complete

**Note:** For large deployments, use the zip method below instead.

### Step 4: Deploy via Azure Portal - Method 2: Zip Deploy (Recommended)

This method is faster for large deployments:

1. **Navigate to your Function App** in Azure Portal
   - Go to **Azure Portal** → **Function Apps**
   - Click on your Function App

2. **Open Advanced Tools (Kudu)**
   - In the left menu, click **Advanced Tools (Kudu)** → **Go**

3. **Navigate to Zip Push Deploy**
   - In Kudu, click **Tools** → **Zip Push Deploy**

4. **Upload your zip file**
   - Click **Choose File** or drag and drop
   - Select `frontend-deploy.zip` (the one you created in Step 2)
   - Click **Upload**
   - Wait for deployment to complete

5. **Verify deployment**
   - Go back to **Debug console** → **CMD**
   - Navigate to `site/wwwroot/`
   - Verify the `static/` folder exists
   - Click into `static/` and verify all files are there

### Step 5: Deploy via Azure Portal - Method 3: Deployment Center

Alternative method using Deployment Center:

1. **Navigate to your Function App** in Azure Portal
   - Go to **Function Apps** → Click your Function App

2. **Open Deployment Center**
   - In the left menu, click **Deployment Center**

3. **Select deployment method**
   - Click **Settings** tab
   - Under **Source**, select **External Git** or **Local Git**
   - Or use **OneDrive**, **Dropbox**, or **Zip Deploy**

4. **For Zip Deploy:**
   - Click **Browse** next to **Package or folder**
   - Select your `frontend-deploy.zip` file
   - Click **Save**
   - Deployment will start automatically

### Step 6: Verify Deployment

1. **Check files in Kudu:**
   - Go to **Advanced Tools (Kudu)** → **Go**
   - **Debug console** → **CMD**
   - Navigate to `site/wwwroot/static/`
   - List files: `dir` (Windows) or `ls` (Linux)
   - Verify `index.html` and other files are present

2. **Test the Function App:**
   - Go back to Function App overview
   - Copy the **URL** (e.g., `https://pa-gcloud15-api.azurewebsites.net`)
   - If you have a function that serves static files, test it:
     - `https://pa-gcloud15-api.azurewebsites.net/api/serve_spa`
   - Or test directly if configured:
     - `https://pa-gcloud15-api.azurewebsites.net/static/index.html`

## Alternative: Using Azure CLI (Faster for Large Deployments)

If you prefer command line (can be run from Azure Cloud Shell):

```bash
# Create zip with static folder
cd frontend
npm run build
cd ..
mkdir -p deploy-temp/static
cp -r frontend/dist/* deploy-temp/static/
cd deploy-temp
zip -r ../frontend-deploy.zip .
cd ..

# Deploy to Function App
az functionapp deployment source config-zip \
  --resource-group pa-gcloud15-rg \
  --name pa-gcloud15-api \
  --src frontend-deploy.zip
```

## Troubleshooting

### Files Not Appearing

**Issue:** Files uploaded but not visible

**Solutions:**
- Refresh the Kudu file explorer
- Check you're in the correct directory (`site/wwwroot/static/`)
- Verify zip file structure: files should be at `static/index.html`, not `deploy-frontend/static/index.html`

### Zip Deploy Fails

**Issue:** Zip deployment fails with error

**Solutions:**
- Ensure zip file is not corrupted
- Check zip file size (Azure has limits)
- Verify zip structure: root should contain `static/` folder directly
- Try uploading individual files via Kudu instead

### Function App Not Serving Files

**Issue:** Files deployed but not accessible

**Solutions:**
- Verify Function App has a function to serve static files
- Check function routing configuration
- Verify `static/` folder is in correct location (`site/wwwroot/static/`)
- Check Function App URL and path configuration

### Large File Upload Timeout

**Issue:** Upload times out for large deployments

**Solutions:**
- Use Zip Deploy method instead of individual file uploads
- Split into smaller batches
- Use Azure CLI with `az functionapp deployment source config-zip`
- Consider using Azure Storage and copying from there

## File Structure After Deployment

Your Function App should have this structure:

```
site/wwwroot/
├── function_app/
│   └── __init__.py
├── static/
│   ├── index.html
│   ├── assets/
│   │   ├── index-abc123.js
│   │   ├── index-def456.css
│   │   └── ...
│   └── ...
├── host.json
└── requirements.txt
```

## Next Steps

After deploying static files:

1. **Configure Function to Serve Static Files:**
   - Ensure your Function App has a function that serves files from `static/` folder
   - Configure routing if needed

2. **Test Frontend:**
   - Access the Function App URL
   - Verify React app loads correctly
   - Test API connections

3. **Update App Settings:**
   - Configure environment variables if needed
   - Update API base URLs if required

## Quick Reference

**Kudu URL Format:**
```
https://<function-app-name>.scm.azurewebsites.net
```

**Direct File Access (if configured):**
```
https://<function-app-name>.azurewebsites.net/static/index.html
```

**Zip Deploy Command:**
```bash
az functionapp deployment source config-zip \
  --resource-group <resource-group> \
  --name <function-app-name> \
  --src <zip-file>
```

