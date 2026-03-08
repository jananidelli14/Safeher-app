"""
SafeHer Enhanced AI Service
100% real-time: Gemini answers everything using live OSM data injected as context.
NO hardcoded place descriptions. NO fake safety ratings. NO made-up tips.
Every response is generated fresh from:
  - User's actual GPS coordinates (OpenStreetMap live query)
  - Current real time (hour, day, date)
  - Gemini's own knowledge of Tamil Nadu
"""

import os
import re
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load .env
for env_path in [
    os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'),
    os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env'),
    '.env',
]:
    if os.path.exists(env_path):
        load_dotenv(dotenv_path=env_path)
        logger.info("[AI] Loaded .env from: %s", env_path)
        break

# ─── Gemini Setup ──────────────────────────────────────────────────────────────
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '').strip()
GEMINI_MODEL   = 'gemini-1.5-flash'
MAX_RETRIES    = 3
BASE_DELAY     = 1.5   # exponential backoff base

_gemini_model = None

def _get_model():
    global _gemini_model
    if _gemini_model:
        return _gemini_model
    if not GEMINI_API_KEY:
        logger.warning("[AI] No GEMINI_API_KEY — please add it to backend/.env")
        return None
    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        _gemini_model = genai.GenerativeModel(GEMINI_MODEL)
        logger.info("[AI] Gemini ready: %s", GEMINI_MODEL)
        return _gemini_model
    except Exception as e:
        logger.error("[AI] Gemini init failed: %s", e)
        return None

# ─── Conversation history (in-memory, per conversation_id) ───────────────────
_histories: Dict[str, List[Dict]] = {}


# ─── Real-time OSM data fetch ─────────────────────────────────────────────────

def _fetch_live_safety_context(lat: float, lng: float) -> str:
    """
    Query OpenStreetMap Overpass API for real police stations and hospitals
    within 10km of the given coordinates. Returns plain text for Gemini.
    """
    try:
        from services.mapillary_service import search_pois_overpass

        police    = search_pois_overpass(lat, lng, 'police',   10000)
        hospitals = search_pois_overpass(lat, lng, 'hospital', 10000)

        lines = []

        if police:
            lines.append(f"NEARBY POLICE STATIONS ({len(police)} found within 10km):")
            for p in police[:5]:
                phone = p.get('phone', 'N/A')
                name  = p.get('name', 'Police Station')
                dist  = p.get('distance_km', '?')
                lines.append(f"  - {name} | {dist} km away | Phone: {phone}")
        else:
            lines.append("NO police stations found within 10km of this location.")

        if hospitals:
            lines.append(f"\nNEARBY HOSPITALS ({len(hospitals)} found within 10km):")
            for h in hospitals[:5]:
                phone = h.get('phone', 'N/A')
                name  = h.get('name', 'Hospital')
                dist  = h.get('distance_km', '?')
                lines.append(f"  - {name} | {dist} km away | Phone: {phone}")
        else:
            lines.append("NO hospitals found within 10km of this location.")

        return "\n".join(lines)

    except Exception as e:
        logger.warning("[AI] OSM fetch error: %s", e)
        return "Live infrastructure data temporarily unavailable."


def _resolve_place_coords(place_name: str) -> Optional[tuple]:
    """
    Try to geocode a place name to lat/lng using Nominatim (OSM geocoding).
    Only used when user mentions a place but hasn't shared GPS.
    """
    try:
        import requests
        url = "https://nominatim.openstreetmap.org/search"
        params = {
            'q': f"{place_name}, Tamil Nadu, India",
            'format': 'json',
            'limit': 1,
            'countrycodes': 'in',
        }
        headers = {'User-Agent': 'SafeHer-App/1.0 (safehertravel@gmail.com)'}
        resp = requests.get(url, params=params, headers=headers, timeout=5)
        results = resp.json()
        if results:
            return float(results[0]['lat']), float(results[0]['lon'])
    except Exception as e:
        logger.warning("[AI] Geocoding error for '%s': %s", place_name, e)
    return None


def _extract_place_from_message(message: str) -> Optional[str]:
    """
    Extract a place name from the user message using simple NLP.
    We don't maintain a hardcoded list — Gemini knows all Tamil Nadu places.
    We just try to find what place the user is asking about.
    """
    msg = message.lower()

    # Common patterns: "at X", "in X", "visit X", "going to X", "about X", "near X"
    patterns = [
        r'(?:at|in|visit|about|near|to|around|going to|travelling to|traveling to|from)\s+([A-Za-z\s]{3,30}?)(?:\s+at|\s+now|\s+tonight|\s+today|\s+safe|\s+is|[?,!]|$)',
        r'([A-Za-z\s]{3,25}?)\s+(?:beach|temple|station|park|road|street|market|mall|nagar|puram|salai|area|town|city)',
    ]
    for pattern in patterns:
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            candidate = match.group(1).strip()
            # Filter out common English words that aren't places
            non_places = {'the','this','that','here','there','it','me','my','now','safe','unsafe','night',
                          'day','time','alone','place','area','location','route','road','way','how','what',
                          'where','when','should','can','will','please','help','i am','i\'m'}
            if candidate.lower() not in non_places and len(candidate) > 2:
                return candidate

    # Fallback: look for capitalized proper nouns
    words = re.findall(r'\b[A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,})*\b', message)
    non_place_words = {'I','The','This','That','Hi','Hello','Hey','Please','Thanks','Sorry',
                       'Is','Are','Was','Were','Will','Can','Do','Does'}
    for w in words:
        if w not in non_place_words:
            return w

    return None


# ─── System prompt — Gemini does ALL the work ─────────────────────────────────

SYSTEM_PROMPT = """You are SafeHer AI, a real-time women's safety assistant for Tamil Nadu, India.

CURRENT DATE AND TIME: {current_datetime}
DAY: {day_of_week}

LIVE INFRASTRUCTURE DATA (fetched right now from OpenStreetMap):
{live_context}

YOUR JOB:
1. Answer the user's safety question using the LIVE data above + your own knowledge of Tamil Nadu.
2. Give TIME-SPECIFIC advice — what's safe at {current_time} may be very different from noon.
3. Use the ACTUAL police station names and distances from the live data above — never make them up.
4. Be warm, caring, and specific. You are a knowledgeable local safety companion.
5. For ANY place the user asks about, give your honest assessment based on what you know + the live data.
6. If the user seems to be in danger, IMMEDIATELY give emergency numbers: Police 100, Emergency 112, Women Helpline 1091.

WHAT YOU MUST NOT DO:
- Do NOT make up police station names or phone numbers not in the live data above.
- Do NOT give vague generic advice. Be specific to the actual place and actual time.
- Do NOT use markdown formatting (no **bold**, no ## headers, no bullet * symbols).
- Use plain text. Use emoji for emphasis. Use numbered lists or bullet points with • or -.

RESPOND in a warm, natural, conversational tone. Be specific. Be real. Be helpful."""


def clean_response(text: str) -> str:
    """Strip markdown so text renders cleanly on mobile."""
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'__(.+?)__', r'\1', text)
    text = re.sub(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', r'\1', text)
    text = re.sub(r'^#{1,4}\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\*\s', '• ', text, flags=re.MULTILINE)
    return text.strip()


# ─── Main entry point ─────────────────────────────────────────────────────────

def get_ai_response(
    user_message: str,
    conversation_id: str,
    user_location: Optional[Dict] = None,
    image_data: Optional[str] = None,
    voice_data: Optional[str] = None,
) -> str:
    """
    Get a real-time safety response from Gemini.
    - Fetches live OSM data for the user's GPS position OR geocoded place name.
    - Injects current time, date, and live infrastructure data into the prompt.
    - Gemini answers using real data — no hardcoded fallback text.
    """
    now          = datetime.now()
    current_time = now.strftime("%I:%M %p")
    current_datetime = now.strftime("%I:%M %p, %A, %d %B %Y")
    day_of_week  = now.strftime("%A")

    # Resolve location for live data
    lat, lng = None, None

    if user_location:
        lat = user_location.get('lat')
        lng = user_location.get('lng')

    # If no GPS, try to geocode the place they're asking about
    if not lat:
        place_name = _extract_place_from_message(user_message)
        if place_name:
            coords = _resolve_place_coords(place_name)
            if coords:
                lat, lng = coords
                logger.info("[AI] Geocoded '%s' to (%.4f, %.4f)", place_name, lat, lng)

    # Fetch live OSM data
    if lat and lng:
        live_context = _fetch_live_safety_context(lat, lng)
    else:
        live_context = "User location not available. No live infrastructure data for this query."

    # Build system prompt with real data injected
    prompt = SYSTEM_PROMPT.format(
        current_datetime=current_datetime,
        day_of_week=day_of_week,
        current_time=current_time,
        live_context=live_context,
    )

    # Build full message
    full_message = f"{prompt}\n\nUser question: {user_message}"
    if voice_data:
        full_message = f"[VOICE MESSAGE TRANSCRIBED] {full_message}"

    content_parts: list = [full_message]
    if image_data:
        content_parts.append({"mime_type": "image/jpeg", "data": image_data})

    model = _get_model()

    if not model:
        return (
            "SafeHer AI needs a Gemini API key to answer real-time questions.\n\n"
            "Please add GEMINI_API_KEY to your backend/.env file.\n"
            "Get your free key at: https://aistudio.google.com/app/apikey\n\n"
            "For emergencies right now:\n"
            "• Police: 100\n"
            "• Emergency: 112\n"
            "• Women Helpline: 1091\n"
            "• Ambulance: 108"
        )

    # Call Gemini with retry on transient errors
    last_error = ""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            # Always start a FRESH chat — this fixes the "connection issue" bug
            # where reused session objects become stale and fail
            chat     = model.start_chat(history=[])
            response = chat.send_message(content_parts)
            ai_text  = clean_response(response.text)

            # Store last 10 messages for context in future turns
            hist = _histories.get(conversation_id, [])
            hist.append({'role': 'user',      'text': user_message})
            hist.append({'role': 'assistant', 'text': ai_text})
            _histories[conversation_id] = hist[-20:]

            logger.info("[AI] Gemini responded successfully (attempt %d)", attempt)
            return ai_text

        except Exception as e:
            last_error  = str(e)
            err_lower   = last_error.lower()
            is_retryable = any(
                kw in err_lower for kw in
                ['429', '503', '500', 'unavailable', 'resource_exhausted',
                 'quota', 'rate limit', 'timeout', 'deadline']
            )

            if is_retryable and attempt < MAX_RETRIES:
                delay = BASE_DELAY * (2 ** (attempt - 1))
                logger.warning(
                    "[AI] Retryable error attempt %d/%d — retrying in %.1fs: %s",
                    attempt, MAX_RETRIES, delay, last_error[:100]
                )
                time.sleep(delay)
                _gemini_model = None   # Reset model object on retry
                _get_model()           # Reinitialize
            else:
                logger.error("[AI] Gemini failed attempt %d/%d: %s", attempt, MAX_RETRIES, last_error[:200])
                break

    # Gemini is down — tell user clearly, give emergency numbers, do NOT fabricate answers
    logger.error("[AI] All retries failed. Last error: %s", last_error[:300])
    return (
        "I'm having trouble connecting to my AI engine right now.\n\n"
        "For your immediate safety, please use these real numbers:\n"
        "• Police: 100\n"
        "• National Emergency: 112\n"
        "• Women Helpline: 1091\n"
        "• Ambulance: 108\n\n"
        "The SOS button in the app works without internet and will alert your emergency contacts.\n\n"
        "Please try your question again in a moment."
    )
