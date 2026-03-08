"""Test the register API endpoint end-to-end"""
import requests
import json

url = "http://localhost:5000/api/user/register"
payload = {
    "name": "Test User",
    "email": "test@safeher.com",
    "password": "Test@1234",
    "phone": "9999999999",
    "city": "Chennai",
    "emergency_contacts": ["9876543210"],
    "health_conditions": "None",
    "consent_agreed": True
}

print("Testing registration...")
resp = requests.post(url, json=payload)
print(f"Status: {resp.status_code}")
print(f"Response: {json.dumps(resp.json(), indent=2)}")
