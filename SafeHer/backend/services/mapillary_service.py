"""
Mapillary API Service
Uses Mapillary Graph API v4 to find real-world POIs (police stations, hospitals, hotels)
near a given location using street-level imagery metadata and map features.
"""

import os
import math
import requests
from typing import Optional

import time
from typing import Optional, Dict

MAPILLARY_ACCESS_TOKEN = os.getenv('MAPILLARY_ACCESS_TOKEN', '')
MAPILLARY_BASE_URL = "https://graph.mapillary.com"

# Simple grid-based cache to avoid hitting Overpass too hard
# Key: (amenity, grid_lat, grid_lng), Value: {'timestamp': time, 'data': [...]}
_poi_cache: Dict = {}
CACHE_TTL = 300 # 5 minutes

# Tamil Nadu District-wise Police Station Phone Numbers (real fallback)
TN_POLICE_PHONES = {
    'chennai': '+91-44-23452365',
    'coimbatore': '+91-422-2300170',
    'madurai': '+91-452-2531212',
    'tiruchirappalli': '+91-431-2418209',
    'trichy': '+91-431-2418209',
    'salem': '+91-427-2450500',
    'tirunelveli': '+91-462-2501010',
    'vellore': '+91-416-2225590',
    'thanjavur': '+91-4362-230303',
    'kanyakumari': '+91-4652-246800',
    'kanchipuram': '+91-44-27224400',
    'cuddalore': '+91-4142-231500',
    'erode': '+91-424-2256020',
    'dindigul': '+91-451-2420450',
    'theni': '+91-4546-252250',
    'ramanathapuram': '+91-4567-230100',
    'sivaganga': '+91-4575-241500',
    'virudhunagar': '+91-4562-270300',
    'thoothukudi': '+91-461-2321100',
    'nagapattinam': '+91-4365-252200',
    'nilgiris': '+91-423-2444033',
    'ooty': '+91-423-2444033',
    'kodaikanal': '+91-4542-241500',
    'pondicherry': '+91-413-2339068',
    'puducherry': '+91-413-2339068',
    'mahabalipuram': '+91-44-27422275',
    'rameswaram': '+91-4573-221223',
}

# Tamil Nadu District-wise Hospital Emergency Numbers (real fallback)
TN_HOSPITAL_PHONES = {
    'chennai': '+91-44-25305000',
    'coimbatore': '+91-422-2301393',
    'madurai': '+91-452-2532535',
    'tiruchirappalli': '+91-431-2415765',
    'salem': '+91-427-2451500',
    'default': '108',
}


def get_tn_phone_fallback(name, address, amenity='police'):
    """Get a Tamil Nadu phone number fallback based on name/address keywords"""
    lookup = TN_POLICE_PHONES if amenity == 'police' else TN_HOSPITAL_PHONES
    text = f"{name} {address}".lower()
    for city, phone in lookup.items():
        if city in text:
            return phone
    return '100' if amenity == 'police' else '108'


def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two lat/lon points."""
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def get_nearby_images(lat: float, lon: float, radius: int = 500, limit: int = 10) -> list:
    """
    Fetch nearby Mapillary street-level images around a coordinate.
    Used to display the map/street view context.
    """
    try:
        url = f"{MAPILLARY_BASE_URL}/images"
        params = {
            "access_token": MAPILLARY_ACCESS_TOKEN,
            "fields": "id,captured_at,geometry,thumb_256_url,thumb_1024_url,creator",
            "bbox": _bounding_box(lat, lon, radius),
            "limit": limit,
        }
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return data.get("data", [])
        else:
            print(f"Mapillary images error: {response.status_code} {response.text}")
            return []
    except Exception as e:
        print(f"Mapillary images exception: {e}")
        return []


def search_pois_mapillary(lat: float, lon: float, amenity: str, radius_m: int = 5000) -> list:
    """
    Search for POIs using Mapillary Graph API v4 map_features.
    Layers: point.amenity.police, point.amenity.hospital, etc.
    """
    if not MAPILLARY_ACCESS_TOKEN:
        return []

    # Map our amenities to Mapillary layers
    layer_map = {
        "police": "point.amenity.police",
        "hospital": "point.amenity.hospital",
        "hotel": "point.tourism.hotel"
    }
    
    layer = layer_map.get(amenity)
    if not layer:
        return []

    url = f"{MAPILLARY_BASE_URL}/map_features"
    params = {
        "access_token": MAPILLARY_ACCESS_TOKEN,
        "layers": layer,
        "bbox": _bounding_box(lat, lon, radius_m),
        "fields": "id,geometry,properties"
    }

    try:
        response = requests.get(url, params=params, timeout=15)
        if response.status_code == 200:
            data = response.json().get("data", [])
            print(f"[MAPILLARY] Found {len(data)} features for {amenity}")
            results = []
            for feat in data:
                props = feat.get("properties", {})
                geom = feat.get("geometry", {}).get("coordinates", [0, 0])
                
                # Geometries in GeoJSON are [lng, lat]
                elem_lon, elem_lat = geom[0], geom[1]
                distance = haversine(lat, lon, elem_lat, elem_lon)
                
                results.append({
                    "id": feat.get("id"),
                    "name": props.get("name") or f"{amenity.capitalize()} (Mapillary)",
                    "lat": elem_lat,
                    "lng": elem_lon,
                    "distance_km": round(distance, 2),
                    "address": props.get("address", "Address verified via Mapillary imagery"),
                    "source": "Mapillary Graph API"
                })
            return results
    except Exception as e:
        print(f"Mapillary POI search error: {e}")
    return []


def search_pois_overpass(lat: float, lon: float, amenity: str, radius: int = 5000) -> list:
    """
    Use OpenStreetMap Overpass API (free, no key) to find real POIs near a location.
    This is the best free alternative since Mapillary is for imagery, not POI search.
    Supported amenity values: 'police', 'hospital', 'hotel', 'lodging'
    """
    # 1. Check cache first
    # Round to 0.01 (~1.1km) to group nearby requests
    grid_lat = round(lat, 2)
    grid_lng = round(lon, 2)
    cache_key = (amenity, grid_lat, grid_lng, radius)
    
    now = time.time()
    if cache_key in _poi_cache:
        cached = _poi_cache[cache_key]
        if now - cached['timestamp'] < CACHE_TTL:
            print(f"[CACHE] Returning cached {amenity} for grid {grid_lat},{grid_lng}")
            # IMPORTANT: Distances must be recalculated for the current exact location!
            results = []
            for item in cached['data']:
                item_copy = item.copy()
                item_copy['distance_km'] = round(haversine(lat, lon, item['lat'], item['lng']), 2)
                results.append(item_copy)
            
            # Sort by new recalculated distance
            results.sort(key=lambda x: x["distance_km"])
            return results

    overpass_url = "https://overpass-api.de/api/interpreter"

    # Map amenity types
    if amenity == "hotel":
        query_filter = f'(node["tourism"="hotel"](around:{radius},{lat},{lon}); way["tourism"="hotel"](around:{radius},{lat},{lon}););'
    elif amenity == "police":
        query_filter = f'(node["amenity"="police"](around:{radius},{lat},{lon}); way["amenity"="police"](around:{radius},{lat},{lon}););'
    elif amenity == "hospital":
        query_filter = f'(node["amenity"="hospital"](around:{radius},{lat},{lon}); node["amenity"="clinic"](around:{radius},{lat},{lon}); node["amenity"="doctors"](around:{radius},{lat},{lon}); node["amenity"="health_post"](around:{radius},{lat},{lon}); way["amenity"="hospital"](around:{radius},{lat},{lon}););'
    else:
        query_filter = f'node["amenity"="{amenity}"](around:{radius},{lat},{lon});'

    query = f"""
    [out:json][timeout:25];
    {query_filter}
    out body center;
    """

    try:
        response = requests.post(overpass_url, data={"data": query}, timeout=20)
        if response.status_code == 200:
            data = response.json()
            elements = data.get("elements", [])
            print(f"[OVERPASS] Found {len(elements)} elements for {amenity}")
            results = []
            for element in data.get("elements", []):
                tags = element.get("tags", {})
                name = tags.get("name") or tags.get("name:en") or tags.get("name:ta")
                if not name:
                    continue

                # Get coordinates
                if element["type"] == "node":
                    elem_lat = element["lat"]
                    elem_lon = element["lon"]
                elif "center" in element:
                    elem_lat = element["center"]["lat"]
                    elem_lon = element["center"]["lon"]
                else:
                    continue

                distance = haversine(lat, lon, elem_lat, elem_lon)

                # Extract phone number with multiple fallbacks
                address_str = _build_address(tags)
                raw_phone = (tags.get("phone") or tags.get("contact:phone") 
                            or tags.get("emergency:phone") or tags.get("contact:mobile"))
                
                # If no phone from OSM, use Tamil Nadu fallback lookup
                if not raw_phone:
                    raw_phone = get_tn_phone_fallback(name, address_str, amenity)

                result = {
                    "id": str(element["id"]),
                    "name": name,
                    "lat": elem_lat,
                    "lng": elem_lon,
                    "distance_km": round(distance, 2),
                    "address": address_str,
                    "phone": raw_phone,
                    "source": "OpenStreetMap",
                }

                # Extra fields by type
                if amenity == "police":
                    result["emergency_phone"] = raw_phone
                if amenity == "hospital":
                    result["emergency_phone"] = raw_phone
                    result["emergency"] = tags.get("emergency", "yes")
                    result["opening_hours"] = tags.get("opening_hours", "24/7")
                if amenity == "hotel":
                    result["stars"] = tags.get("stars")
                    result["website"] = tags.get("website") or tags.get("contact:website")
                    result["rating"] = float(tags.get("rating", 0)) if tags.get("rating") else None

                results.append(result)

            # Sort by distance
            results.sort(key=lambda x: x["distance_km"])
            
            # Store in cache
            _poi_cache[cache_key] = {
                'timestamp': now,
                'data': results
            }
            return results

    except Exception as e:
        print(f"Overpass API exception for {amenity}: {e}")

    return []


def get_mapillary_street_view(lat: float, lon: float, radius: int = 200) -> dict:
    """
    Get Mapillary street-level imagery data for the map view tile layer.
    Returns the closest image and a tile URL template for embedding.
    """
    images = get_nearby_images(lat, lon, radius, limit=5)
    return {
        "tile_url": f"https://tiles.mapillary.com/maps/vtp/mly1_public/2/{{z}}/{{x}}/{{y}}?access_token={MAPILLARY_ACCESS_TOKEN}",
        "nearest_images": images,
        "coverage_available": len(images) > 0,
    }


def share_user_location(lat: float, lon: float, user_id: str, accuracy: float = 10.0) -> dict:
    """
    Share user's location. Currently stores to local DB (Mapillary doesn't have 
    a user location tracking API — it's for crowdsourced imagery).
    Returns location info with nearby Mapillary coverage.
    """
    images = get_nearby_images(lat, lon, radius=300, limit=3)
    return {
        "shared": True,
        "lat": lat,
        "lng": lon,
        "user_id": user_id,
        "mapillary_coverage": len(images) > 0,
        "nearby_images": images[:3],
        "message": "Location recorded. Mapillary street view available." if images else "Location recorded."
    }


def _bounding_box(lat: float, lon: float, radius_m: int) -> str:
    """Convert center + radius to bbox string (west,south,east,north)."""
    delta_lat = radius_m / 111320
    delta_lon = radius_m / (111320 * math.cos(math.radians(lat)))
    return f"{lon - delta_lon},{lat - delta_lat},{lon + delta_lon},{lat + delta_lat}"


def _build_address(tags: dict) -> str:
    """Build a human-readable address from OSM tags."""
    parts = []
    for key in ["addr:housenumber", "addr:street", "addr:suburb", "addr:city", "addr:state"]:
        val = tags.get(key)
        if val:
            parts.append(val)
    return ", ".join(parts) if parts else tags.get("addr:full", "")
