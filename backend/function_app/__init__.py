import sys
import logging
from pathlib import Path

import azure.functions as func
from azure.functions import AsgiMiddleware

# Set up logging to see what's happening
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("=" * 50)
logger.info("Function App entry point starting...")
logger.info("=" * 50)

# Ensure the FastAPI application package is on sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))
    logger.info(f"Added {ROOT_DIR} to sys.path")

logger.info(f"ROOT_DIR: {ROOT_DIR}")
logger.info(f"Python path: {sys.path[:3]}")

try:
    logger.info("Attempting to import app.main...")
    from app.main import app
    logger.info("✓ Successfully imported app.main")
    logger.info(f"FastAPI app title: {app.title}")
    logger.info(f"FastAPI app routes count: {len(app.routes)}")
    
    # Log all routes
    for route in app.routes:
        if hasattr(route, 'path') and hasattr(route, 'methods'):
            logger.info(f"  Route: {list(route.methods)} {route.path}")
    
except Exception as e:
    logger.error(f"✗ Failed to import app.main: {e}", exc_info=True)
    raise

try:
    logger.info("Creating AsgiMiddleware handler...")
    asgi_handler = AsgiMiddleware(app)
    logger.info("✓ AsgiMiddleware handler created")
except Exception as e:
    logger.error(f"✗ Failed to create AsgiMiddleware: {e}", exc_info=True)
    raise

logger.info("=" * 50)
logger.info("Function App entry point ready!")
logger.info("=" * 50)


async def main(req: func.HttpRequest, context: func.Context) -> func.HttpResponse:
    """Azure Functions entry point wrapping the FastAPI application."""
    logger.info(f"Received request: {req.method} {req.url}")
    try:
        response = await asgi_handler.handle_async(req, context)
        logger.info(f"Request handled: {response.status_code}")
        return response
    except Exception as e:
        logger.error(f"Error handling request: {e}", exc_info=True)
        raise

