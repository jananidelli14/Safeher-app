"""
Location Routes
Real-time location tracking and sharing
"""

from flask import Blueprint, request, jsonify
from datetime import datetime
from database.db import get_db_connection
import uuid

location_bp = Blueprint('location', __name__)

# Store active location shares (in production, use Redis)
active_shares = {}

@location_bp.route('/update', methods=['POST'])
def update_location():
    """
    Update user's current location
    Request body: {
        "user_id": "string",
        "latitude": float,
        "longitude": float,
        "accuracy": float (optional)
    }
    """
    try:
        data = request.json
        user_id = data.get('user_id')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        accuracy = data.get('accuracy', 0)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO location_history (id, user_id, latitude, longitude, accuracy, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (str(uuid.uuid4()), user_id, latitude, longitude, accuracy, datetime.now()))
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Location updated successfully',
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@location_bp.route('/share', methods=['POST'])
def share_location():
    """
    Share live location with emergency contacts
    Request body: {
        "user_id": "string",
        "contacts": ["phone1", "phone2"],
        "duration_minutes": int (default 60)
    }
    """
    try:
        data = request.json
        user_id = data.get('user_id')
        contacts = data.get('contacts', [])
        duration = data.get('duration_minutes', 60)
        
        share_id = str(uuid.uuid4())
        
        active_shares[share_id] = {
            'user_id': user_id,
            'contacts': contacts,
            'started_at': datetime.now().isoformat(),
            'duration_minutes': duration,
            'active': True
        }
        
        # Send sharing link to contacts via SMS
        from services.notification_service import send_sms
        share_link = f"https://safehertravel.com/track/{share_id}"
        
        for contact in contacts:
            message = f"Location sharing activated. Track here: {share_link}"
            send_sms(contact, message)
        
        return jsonify({
            'success': True,
            'share_id': share_id,
            'share_link': share_link,
            'expires_at': duration
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@location_bp.route('/track/<share_id>', methods=['GET'])
def track_location(share_id):
    """Get shared location data"""
    if share_id in active_shares:
        share = active_shares[share_id]
        
        # Get latest location
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM location_history
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT 1
        """, (share['user_id'],))
        
        location = cursor.fetchone()
        conn.close()
        
        return jsonify({
            'success': True,
            'location': dict(location) if location else None,
            'share_info': share
        }), 200
    else:
        return jsonify({
            'success': False,
            'error': 'Share not found or expired'
        }), 404

@location_bp.route('/history/<user_id>', methods=['GET'])
def get_location_history(user_id):
    """Get location history for a user"""
    try:
        limit = int(request.args.get('limit', 100))
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM location_history
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT ?
        """, (user_id, limit))
        
        history = cursor.fetchall()
        conn.close()
        
        return jsonify({
            'success': True,
            'history': [dict(loc) for loc in history]
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500