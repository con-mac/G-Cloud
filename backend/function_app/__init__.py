import sys
from pathlib import Path

import azure.functions as func
from azure.functions import AsgiMiddleware

# Ensure the FastAPI application package is on sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from app.main import app

asgi_handler = AsgiMiddleware(app)


async def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    """Azure Functions entry point wrapping the FastAPI application."""
    return await asgi_handler.handle_async(req, context)

