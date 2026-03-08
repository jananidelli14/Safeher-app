"""
Community Routes - Tourist Experience Sharing
Allows users to share and read travel experiences.
Auto-seeds Tamil Nadu tourist feedback on first run.
"""

from flask import Blueprint, request, jsonify
from datetime import datetime
import uuid
from database.db import get_db_connection

community_bp = Blueprint('community', __name__)

_seeded = False


def _auto_seed_if_empty():
    """Automatically seed community with Tamil Nadu tourist feedback if empty"""
    global _seeded
    if _seeded:
        return
    _seeded = True
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Ensure table exists with is_verified column
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS community_posts (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                user_name TEXT,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                location_name TEXT,
                category TEXT DEFAULT 'experience',
                likes INTEGER DEFAULT 0,
                is_verified INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        
        # Check for is_verified column (may not exist in older DBs)
        cursor.execute("PRAGMA table_info(community_posts)")
        columns = [col[1] for col in cursor.fetchall()]
        if 'is_verified' not in columns:
            cursor.execute("ALTER TABLE community_posts ADD COLUMN is_verified INTEGER DEFAULT 0")
            conn.commit()
        
        cursor.execute("SELECT COUNT(*) FROM community_posts")
        count = cursor.fetchone()[0]
        conn.close()
        
        if count < 5:
            print("[COMMUNITY] Empty or low content — auto-seeding tourist feedback...")
            from seed_community import seed_community
            seed_community()
            print("[COMMUNITY] Auto-seed complete!")
    except Exception as e:
        print(f"[COMMUNITY SEED ERROR] {e}")


@community_bp.route('/posts', methods=['GET'])
def get_posts():
    """Get community posts, with optional category filter."""
    _auto_seed_if_empty()
    
    try:
        category = request.args.get('category')
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if category and category != 'all':
            cursor.execute("""
                SELECT * FROM community_posts 
                WHERE category = ? 
                ORDER BY created_at DESC LIMIT 50
            """, (category,))
        else:
            cursor.execute("""
                SELECT * FROM community_posts ORDER BY created_at DESC LIMIT 50
            """)
            
        rows = cursor.fetchall()
        conn.close()
        posts = [dict(row) for row in rows]
        return jsonify({'success': True, 'posts': posts}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@community_bp.route('/posts', methods=['POST'])
def create_post():
    """Create a new community post."""
    try:
        data = request.json
        title = data.get('title', '').strip()
        content = data.get('content', '').strip()
        location_name = data.get('location_name', '').strip()
        user_id = data.get('user_id', 'anonymous')
        user_name = data.get('user_name', 'Traveler')
        category = data.get('category', 'experience')

        if not title or not content:
            return jsonify({'success': False, 'error': 'Title and content are required'}), 400

        post_id = str(uuid.uuid4())
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO community_posts (id, user_id, user_name, title, content, location_name, category, likes, is_verified, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, ?)
        """, (post_id, user_id, user_name, title, content, location_name, category, datetime.now()))
        conn.commit()
        conn.close()

        return jsonify({'success': True, 'post_id': post_id, 'message': 'Post created successfully'}), 201
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@community_bp.route('/posts/<post_id>/like', methods=['POST'])
def like_post(post_id):
    """Like a post."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE community_posts SET likes = likes + 1 WHERE id = ?", (post_id,))
        conn.commit()
        cursor.execute("SELECT likes FROM community_posts WHERE id = ?", (post_id,))
        row = cursor.fetchone()
        conn.close()
        if not row:
            return jsonify({'success': False, 'error': 'Post not found'}), 404
        return jsonify({'success': True, 'likes': row['likes']}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@community_bp.route('/seed', methods=['POST'])
def seed_posts():
    """Manually trigger community seeding (dev endpoint)."""
    try:
        from seed_community import seed_community
        count = seed_community()
        return jsonify({'success': True, 'seeded': count, 'message': f'{count} posts seeded'}), 200
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
