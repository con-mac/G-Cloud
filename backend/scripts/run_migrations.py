"""Run database migrations"""

import sys
import os

# Import alembic first (before adding /app to avoid conflicts)
from alembic.config import Config
from alembic import command

# Now add the app directory to the path for models
sys.path.append('/app')

# Get the alembic configuration
alembic_cfg = Config("/app/alembic.ini")

# Run the migrations
try:
    print("Running database migrations...")
    command.upgrade(alembic_cfg, "head")
    print("✅ Migrations completed successfully!")
except Exception as e:
    print(f"❌ Migration failed: {e}")
    sys.exit(1)

