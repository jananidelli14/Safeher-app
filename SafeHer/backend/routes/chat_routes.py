"""
Chat Routes — AI Safety Chatbot
JWT-protected. Stores messages in Supabase PostgreSQL.
"""

import logging
import uuid
from datetime import datetime
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from services.enhanced_ai_service import get_ai_response
from database.db import get_db_connection, close_connection

logger = logging.getLogger(__name__)
chat_bp = Blueprint('chat', __name__)


# ─── Send Message ─────────────────────────────────────────────────────────────

@chat_bp.route('/message', methods=['POST'])
@jwt_required()
def send_message():
    """
    POST /api/chat/message
    Header: Authorization: Bearer <access_token>
    Body: { "message": string, "conversation_id"?: string, "user_location"?: { lat, lng } }
    Returns: { success, response, conversation_id, timestamp }
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        data = request.get_json(force=True) or {}

        message = (data.get('message') or '').strip()
        if not message:
            return jsonify({'success': False, 'error': 'Message cannot be empty'}), 400

        conversation_id = data.get('conversation_id') or str(uuid.uuid4())
        user_location   = data.get('user_location')
        image_data      = data.get('image')
        voice_data      = data.get('voice')

        conn = get_db_connection()
        cursor = conn.cursor()

        # Save user message
        cursor.execute(
            """
            INSERT INTO chat_messages (id, user_id, conversation_id, message, response, sender, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (str(uuid.uuid4()), user_id, conversation_id, message, None, 'user', datetime.utcnow()),
        )
        conn.commit()

        # Get AI response
        ai_response = get_ai_response(
            message,
            conversation_id,
            user_location,
            image_data=image_data,
            voice_data=voice_data,
        )

        # Save AI response
        cursor.execute(
            """
            INSERT INTO chat_messages (id, user_id, conversation_id, message, response, sender, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (str(uuid.uuid4()), user_id, conversation_id, ai_response, None, 'assistant', datetime.utcnow()),
        )
        conn.commit()

        return jsonify({
            'success': True,
            'conversation_id': conversation_id,
            'response': ai_response,
            'timestamp': datetime.utcnow().isoformat(),
        }), 200

    except Exception as e:
        logger.error("Chat message error: %s", e)
        if conn:
            conn.rollback()
        return jsonify({'success': False, 'error': 'Chat service temporarily unavailable'}), 500
    finally:
        close_connection(conn)


# ─── Chat History ─────────────────────────────────────────────────────────────

@chat_bp.route('/history', methods=['GET'])
@jwt_required()
def get_chat_history():
    """
    GET /api/chat/history?limit=20
    Returns the last N messages for this user.
    """
    conn = None
    try:
        user_id = get_jwt_identity()
        limit = min(int(request.args.get('limit', 20)), 100)

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT id, conversation_id, message, sender, created_at
            FROM chat_messages
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (user_id, limit),
        )
        messages = cursor.fetchall()

        return jsonify({
            'success': True,
            'messages': [
                {**dict(m), 'created_at': str(m['created_at'])}
                for m in reversed(messages)
            ],
        }), 200

    except Exception as e:
        logger.error("Chat history error: %s", e)
        return jsonify({'success': False, 'error': 'Could not fetch chat history'}), 500
    finally:
        close_connection(conn)


# ─── Safety Tips (public) ─────────────────────────────────────────────────────

@chat_bp.route('/safety-tips', methods=['GET'])
def get_safety_tips():
    """GET /api/chat/safety-tips — no auth required"""
    tips = [
        {'id': 1, 'title': 'Share Your Location', 'description': 'Always share your live location with trusted contacts when traveling alone.', 'category': 'prevention'},
        {'id': 2, 'title': 'Trust Your Instincts', 'description': 'If a situation feels unsafe, remove yourself immediately.', 'category': 'awareness'},
        {'id': 3, 'title': 'Keep Phone Charged', 'description': 'Ensure your phone has sufficient battery when traveling.', 'category': 'preparation'},
        {'id': 4, 'title': 'Avoid Isolated Areas', 'description': 'Stay in well-lit, populated areas especially at night.', 'category': 'prevention'},
        {'id': 5, 'title': 'Use Verified Transport', 'description': 'Only use registered and verified transportation services.', 'category': 'transport'},
    ]
    return jsonify({'success': True, 'tips': tips}), 200

# ─── Direct Gemini proxy (no auth, for web CORS bypass) ──────────────────────

@chat_bp.route('/direct', methods=['POST', 'OPTIONS'])
def direct_gemini():
    """
    POST /api/chat/direct  — no JWT required
    Proxies to Gemini so Flutter Web avoids CORS issues.
    Body: { "message": str, "location": {"lat": float, "lng": float} (optional) }
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200

    try:
        import google.generativeai as genai
        import os
        from datetime import datetime

        data    = request.get_json(force=True) or {}
        message = (data.get('message') or '').strip()
        if not message:
            return jsonify({'success': False, 'error': 'Empty message'}), 400

        loc  = data.get('location') or {}
        lat  = loc.get('lat')
        lng  = loc.get('lng')
        now  = datetime.now()

        loc_ctx = (f"User location: {lat:.4f}, {lng:.4f} (Tamil Nadu, India)."
                   if lat and lng else "User location: Tamil Nadu, India.")

        system = (
            f"You are SafeHer AI, a travel safety assistant for Tamil Nadu, India. "
            f"{loc_ctx} "
            f"Current time: {now.strftime('%I:%M %p, %A')}. "
            f"Answer safety questions about Tamil Nadu — police stations, hospitals, safe routes, "
            f"travel tips, emergency numbers. Keep replies concise and helpful. "
            f"Always include relevant emergency numbers: Police 100, Emergency 112, Women Helpline 1091. "
            f"Reply in the same language the user uses (Tamil or English)."
        )

        api_key = os.getenv('GEMINI_API_KEY', '').strip()
        genai.configure(api_key=api_key)
        model   = genai.GenerativeModel('gemini-1.5-flash')
        result  = model.generate_content(f"{system}\n\nUser: {message}")
        reply   = result.text if result.text else "I'm here to help with your safety in Tamil Nadu."

        return jsonify({'success': True, 'response': reply}), 200

    except Exception as e:
        logger.error("Direct Gemini error: %s", e)
        return jsonify({
            'success': False,
            'response': (
                "SafeHer AI is available. For emergencies:\n"
                "• Police: 100\n• Emergency: 112\n• Women Helpline: 1091\n• Ambulance: 108"
            )
        }), 200
