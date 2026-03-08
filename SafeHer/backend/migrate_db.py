import sqlite3
import os

DATABASE_PATH = 'safeher_travel.db'

def migrate():
    if not os.path.exists(DATABASE_PATH):
        print(f"❌ Database file {DATABASE_PATH} not found. Run setup_database.py first.")
        return

    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()

    columns_to_add = [
        ('city', 'TEXT'),
        ('health_conditions', 'TEXT'),
        ('consent_agreed', 'INTEGER DEFAULT 0')
    ]

    print("🚀 Starting database migration...")

    for column_name, column_type in columns_to_add:
        try:
            print(f"➕ Adding column '{column_name}'...")
            cursor.execute(f"ALTER TABLE users ADD COLUMN {column_name} {column_type}")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e).lower():
                print(f"ℹ️ Column '{column_name}' already exists, skipping.")
            else:
                print(f"❌ Error adding column '{column_name}': {e}")
    
    # Also ensure user_sessions table exists (referenced in user_routes.py but missing from setup_database.py)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            token TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id)
        )
    """)
    print("✅ Ensured 'user_sessions' table exists.")

    conn.commit()
    conn.close()
    print("🎉 Migration completed successfully!")

if __name__ == '__main__':
    migrate()
