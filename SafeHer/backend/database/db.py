"""
Database Module – Supabase PostgreSQL via psycopg2
Replaces the old SQLite connection layer.
"""

import os
import logging
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

def get_db_connection():
    """
    Open and return a psycopg2 connection to Supabase PostgreSQL.
    Cursor factory is RealDictCursor so rows behave like dicts.
    Re-reads DATABASE_URL on every call so .env changes take effect.
    """
    load_dotenv(override=True)
    db_url = os.getenv('DATABASE_URL')
    if not db_url:
        raise RuntimeError(
            "DATABASE_URL is not set. "
            "Add it to your .env file: "
            "postgresql://postgres:PASSWORD@db.REF.supabase.co:5432/postgres"
        )
    try:
        conn = psycopg2.connect(
            db_url,
            cursor_factory=psycopg2.extras.RealDictCursor,
            connect_timeout=10,
            sslmode='require',
        )
        return conn
    except psycopg2.Error as e:
        logger.error("Database connection failed: %s", e)
        raise


def close_connection(conn):
    """Safely close a database connection."""
    try:
        if conn and not conn.closed:
            conn.close()
    except Exception as e:
        logger.warning("Error closing DB connection: %s", e)