"""
Report Routes
Allows users to report incidents and suspicious activities
"""

from flask import Blueprint, request, jsonify
from datetime import datetime
from database.db import get_db_connection
import uuid

report_bp = Blueprint('report', __name__)

@report_bp.route('/submit', methods=['POST'])
def submit_report():
    """
    Submit a safety report
    Request body: {
        "user_id": "string",
        "type": "string",
        "description": "string",
        "location": {"lat": float, "lng": float}
    }
    """
    try:
        data = request.json
        user_id = data.get('user_id')
        report_type = data.get('type')
        description = data.get('description')
        location = data.get('location', {})
        
        report_id = str(uuid.uuid4())
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO reports (id, user_id, type, description, latitude, longitude, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            report_id, 
            user_id, 
            report_type, 
            description, 
            location.get('lat'), 
            location.get('lng'),
            'submitted',
            datetime.now()
        ))
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'report_id': report_id,
            'message': 'Your report has been received and is being processed by the safety team.',
            'timestamp': datetime.now().isoformat()
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@report_bp.route('/history/<user_id>', methods=['GET'])
def get_report_history(user_id):
    """Get history of reports for a user"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE user_id = ? ORDER BY created_at DESC", (user_id,))
        reports = cursor.fetchall()
        conn.close()
        
        return jsonify({
            'success': True,
            'reports': [dict(r) for r in reports]
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
