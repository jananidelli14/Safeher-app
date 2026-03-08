"""
Notification Service — SafeHer
SMS via Twilio, WhatsApp deep links, and email via SendGrid.
All credentials come from environment variables — never hardcoded.
"""

import os
import urllib.parse
import logging

logger = logging.getLogger(__name__)

# ─── Twilio Configuration ──────────────────────────────────────────────────────
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID')
TWILIO_AUTH_TOKEN  = os.getenv('TWILIO_AUTH_TOKEN')
TWILIO_PHONE_NUMBER = os.getenv('TWILIO_PHONE_NUMBER')  # e.g. +1XXXXXXXXXX

# ─── SendGrid Configuration ────────────────────────────────────────────────────
SENDGRID_API_KEY = os.getenv('SENDGRID_API_KEY')
FROM_EMAIL = os.getenv('FROM_EMAIL', 'noreply@safehertravel.com')


def send_sms(to_phone: str, message: str) -> bool:
    """
    Send SMS using Twilio.
    If Twilio credentials are missing, logs a simulation (for local dev).

    Args:
        to_phone: Recipient phone number with country code (e.g. +919876543210)
        message:  SMS text content

    Returns:
        True on success, False on failure.
    """
    if not to_phone or not to_phone.strip():
        logger.warning("[SMS] No phone number provided — skipping")
        return False

    # Clean phone number
    clean_phone = ''.join(c for c in to_phone if c.isdigit() or c == '+')
    if not clean_phone.startswith('+'):
        clean_phone = '+91' + clean_phone  # Default to India if no country code

    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN or not TWILIO_PHONE_NUMBER:
        # Simulation mode — print to logs (useful for dev without Twilio creds)
        logger.info("[SMS SIMULATION] To: %s", clean_phone)
        logger.info("[SMS SIMULATION] Message: %s", message[:120])
        return True

    try:
        from twilio.rest import Client
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        msg_obj = client.messages.create(
            body=message,
            from_=TWILIO_PHONE_NUMBER,
            to=clean_phone,
        )
        logger.info("[SMS] Sent successfully to %s | SID: %s", clean_phone, msg_obj.sid)
        return True

    except Exception as e:
        logger.error("[SMS] Failed to send to %s: %s", clean_phone, e)
        return False


def send_email(to_email: str, subject: str, content: str) -> bool:
    """
    Send email using SendGrid.
    Falls back to simulation if SendGrid API key is missing.
    """
    if not to_email:
        return False

    if not SENDGRID_API_KEY:
        logger.info("[EMAIL SIMULATION] To: %s | Subject: %s", to_email, subject)
        return True

    try:
        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail

        mail = Mail(
            from_email=FROM_EMAIL,
            to_emails=to_email,
            subject=subject,
            html_content=content,
        )
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(mail)
        logger.info("[EMAIL] Sent to %s | Status: %s", to_email, response.status_code)
        return True

    except Exception as e:
        logger.error("[EMAIL] Failed to send to %s: %s", to_email, e)
        return False


def send_sos_sms(to_phone: str, user_name: str, location: dict) -> bool:
    """Send SOS emergency SMS to a contact or police station."""
    lat = location.get('lat', '')
    lng = location.get('lng', '')
    map_link = f"https://maps.google.com/?q={lat},{lng}"

    message = (
        f"🚨 EMERGENCY SOS — SafeHer\n\n"
        f"{user_name} has activated an SOS alert and needs IMMEDIATE help!\n\n"
        f"📍 Location: {map_link}\n\n"
        f"Please call them or contact emergency services NOW.\n"
        f"Police: 100 | Emergency: 112 | Women Helpline: 1091"
    )
    return send_sms(to_phone, message)


def send_sos_email(to_email: str, user_name: str, location: dict) -> bool:
    """Send SOS emergency email to a contact."""
    lat = location.get('lat', '')
    lng = location.get('lng', '')
    map_link = f"https://maps.google.com/?q={lat},{lng}"

    subject = f"🚨 EMERGENCY: {user_name} needs help NOW — SafeHer"
    content = f"""
    <html>
    <body style="font-family: -apple-system, Arial, sans-serif; background: #f9f9f9; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(233,30,140,0.15);">
        <div style="background: linear-gradient(135deg, #E91E8C, #9C27B0); padding: 24px 28px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 22px;">🚨 EMERGENCY ALERT</h1>
          <p style="color: rgba(255,255,255,0.85); margin: 8px 0 0; font-size: 14px;">SafeHer — Tamil Nadu Women Safety</p>
        </div>
        <div style="padding: 28px;">
          <p style="font-size: 16px; color: #2D1B35; font-weight: bold;">{user_name} has activated an emergency SOS!</p>
          <p style="color: #666; line-height: 1.6;">This is an automated alert from the SafeHer app. {user_name} may be in danger and needs your immediate attention.</p>

          <div style="background: #FFF0F8; border: 1px solid #FFD6EC; border-radius: 12px; padding: 20px; margin: 20px 0;">
            <p style="margin: 0 0 8px; font-weight: bold; color: #E91E8C;">📍 Current Location</p>
            <p style="margin: 0; color: #666; font-size: 13px;">Lat: {lat}, Lng: {lng}</p>
            <a href="{map_link}" style="display: inline-block; margin-top: 12px; background: linear-gradient(135deg, #E91E8C, #9C27B0); color: white; padding: 10px 20px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 14px;">
              📍 Open in Google Maps
            </a>
          </div>

          <div style="background: #FFEBEE; border-radius: 12px; padding: 16px; margin: 16px 0;">
            <p style="margin: 0 0 8px; font-weight: bold; color: #B71C1C;">⚡ Immediate Action Required</p>
            <ol style="margin: 0; padding-left: 20px; color: #666; line-height: 1.8;">
              <li>Try to call {user_name} immediately</li>
              <li>If no response, call <strong>Police: 100</strong> or <strong>Emergency: 112</strong></li>
              <li>Share location with local authorities</li>
            </ol>
          </div>

          <div style="border: 1px solid #E0E0E0; border-radius: 8px; padding: 14px;">
            <p style="margin: 0 0 6px; font-weight: bold; color: #333; font-size: 13px;">Tamil Nadu Emergency Numbers</p>
            <p style="margin: 0; color: #666; font-size: 13px;">
              🚔 Police: <strong>100</strong> &nbsp;|&nbsp;
              🏥 Ambulance: <strong>108</strong> &nbsp;|&nbsp;
              🆘 Emergency: <strong>112</strong> &nbsp;|&nbsp;
              👩 Women Helpline: <strong>1091</strong>
            </p>
          </div>
        </div>
        <div style="background: #F3E5FF; padding: 14px 28px; text-align: center;">
          <p style="margin: 0; font-size: 11px; color: #9C27B0;">This alert was sent by SafeHer — Tamil Nadu Women Safety App</p>
        </div>
      </div>
    </body>
    </html>
    """
    return send_email(to_email, subject, content)


def generate_whatsapp_links(contacts: list, user_name: str, location: dict) -> list:
    """
    Generate WhatsApp deep links (wa.me) for emergency contacts.
    Flutter opens these links to pre-fill a WhatsApp message.

    Args:
        contacts: List of phone numbers
        user_name: Name of the SOS sender
        location:  Dict with 'lat' and 'lng'

    Returns:
        List of WhatsApp link strings
    """
    lat = location.get('lat', '')
    lng = location.get('lng', '')
    map_link = f"https://maps.google.com/?q={lat},{lng}"

    message = (
        f"🚨 EMERGENCY ALERT from SafeHer!\n\n"
        f"{user_name} has triggered an SOS and needs immediate help!\n\n"
        f"📍 Location: {map_link}\n\n"
        f"Please call them or contact emergency services NOW.\n"
        f"Police: 100 | Emergency: 112 | Women Helpline: 1091"
    )
    encoded_message = urllib.parse.quote(message)

    links = []
    for phone in contacts:
        if not phone:
            continue
        clean = ''.join(c for c in phone if c.isdigit() or c == '+')
        if not clean.startswith('+'):
            clean = '+91' + clean
        wa_phone = clean.lstrip('+')
        links.append(f"https://wa.me/{wa_phone}?text={encoded_message}")

    return links


def send_location_share_sms(to_phone: str, user_name: str, share_link: str) -> bool:
    """Notify a contact that someone is sharing their live location."""
    message = (
        f"📍 SafeHer Location Share\n\n"
        f"{user_name} is sharing their live location with you.\n\n"
        f"Track here: {share_link}\n\n"
        f"This link is active while they are traveling."
    )
    return send_sms(to_phone, message)
