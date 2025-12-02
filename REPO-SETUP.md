# Repository Setup - CORRECTED

## Repository Structure

- **PUBLIC Repo (G-Cloud)**: https://github.com/con-mac/G-Cloud.git
  - **ONLY** contains `pa-deployment/` folder
  - This is what the PA dev team will use
  - This is the MAIN working repository for PA deployment

- **PRIVATE Repo (g-cloud-v15)**: https://github.com/con-mac/g-cloud-v15.git
  - Contains the full codebase (backend, frontend, infrastructure, etc.)
  - Used for personal development
  - Not shared with PA team

## Current Setup

**Default remote (origin)**: PUBLIC repo (G-Cloud) - for PA deployment work
**Secondary remote (private)**: PRIVATE repo (g-cloud-v15) - for full codebase

## Working with the Public Repo

### For PA Deployment Work:
```powershell
# Make sure you're using the public repo
git remote -v
# Should show: origin -> G-Cloud.git

# Pull latest changes
git pull origin main

# Work normally - all changes go to public repo
git add .
git commit -m "Your changes"
git push origin main
```

### To Update Public Repo with Only pa-deployment:
If you've made changes in the private repo and want to update the public repo:

```powershell
# Use the push script to push only pa-deployment folder
.\pa-deployment\push-to-public-repo.ps1
```

## Important Notes

- The public repo should ONLY contain `pa-deployment/` folder
- If you see other folders (backend, frontend, etc.) in the public repo, they need to be cleaned up
- Use `push-to-public-repo.ps1` to ensure only pa-deployment is pushed

