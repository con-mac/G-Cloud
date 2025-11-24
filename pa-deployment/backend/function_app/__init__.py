"""
Azure Functions entry point for PA deployment
Uses SharePoint instead of Azure Blob Storage
"""

import azure.functions as func
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.main import app

# Create Azure Functions handler
def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    """Azure Functions HTTP trigger handler"""
    return func.WsgiMiddleware(app.wsgi_app).handle(req, context)

