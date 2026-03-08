import requests
import json
import base64

BASE_URL = "http://localhost:5000/api"

def test_sos_activation():
    print("\n--- Testing SOS Activation ---")
    payload = {
        "user_id": "test_user_multimodal",
        "location": {"lat": 13.0417, "lng": 80.2338}, # T Nagar, Chennai
        "emergency_contacts": ["+91-TEST-CONTACT"]
    }
    response = requests.post(f"{BASE_URL}/sos/activate", json=payload)
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Message: {data.get('message')}")
    print(f"Primary Police: {data.get('police_station', {}).get('name')}")
    print(f"Total Police Stations Alerted: {len(data.get('all_police_stations', []))}")
    assert data['success'] is True
    assert len(data.get('all_police_stations', [])) > 0

def test_ai_multimodal_chat():
    print("\n--- Testing AI Multimodal Chat ---")
    # Mock image (just a tiny valid jpeg base64 if possible, otherwise just a string)
    # Using a 1x1 black pixel base64
    mock_image = "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhc_id_id_id_id_id_id_id"
    
    payload = {
        "user_id": "test_user_multimodal",
        "message": "I am at T Nagar. Is it safe here?",
        "user_location": {"lat": 13.0417, "lng": 80.2338},
        "image": mock_image
    }
    response = requests.post(f"{BASE_URL}/chat/message", json=payload)
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"AI Response: {data.get('response')[:200]}...")
    assert data['success'] is True

def test_incident_reporting():
    print("\n--- Testing Incident Reporting ---")
    payload = {
        "user_id": "test_user_multimodal",
        "type": "Suspicious Activity",
        "description": "Saw someone following me near Egmore station",
        "location": {"lat": 13.0732, "lng": 80.2609}
    }
    response = requests.post(f"{BASE_URL}/report/submit", json=payload)
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Message: {data.get('message')}")
    print(f"Report ID: {data.get('report_id')}")
    assert data['success'] is True

if __name__ == "__main__":
    try:
        test_sos_activation()
        test_ai_multimodal_chat()
        test_incident_reporting()
        print("\n✅ ALL ENHANCEMENT TESTS PASSED!")
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
