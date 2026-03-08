"""Quick test: can we connect to Supabase?"""
import psycopg2
import psycopg2.extras

try:
    conn = psycopg2.connect(
        host="aws-1-ap-northeast-1.pooler.supabase.com",
        port=5432,
        dbname="postgres",
        user="postgres.mzeqleiwqnweccgmymxc",
        password="Supabase@2005",
        sslmode="require",
        connect_timeout=10,
        cursor_factory=psycopg2.extras.RealDictCursor,
    )
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) as cnt FROM users")
    row = cur.fetchone()
    print("SUCCESS! Connected to Supabase PostgreSQL.")
    print("Users in database:", row["cnt"])
    conn.close()
except Exception as e:
    print("FAILED:", e)
