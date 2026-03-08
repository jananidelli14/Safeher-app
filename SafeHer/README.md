# Safe Her Travel 🛡️

A modern safety application featuring SOS alerts, safe accommodation discovery, and an AI-powered safety companion.

## 🚀 Getting Started for the Team

If you are cloning this repo for the first time, follow these steps to avoid errors.

### 1. Backend Setup
1. Navigate to the backend folder: `cd backend`
2. Install dependencies: `pip install -r requirements.txt`
3. **Initialize the Database**: `python setup_database.py` (This fixes the "no column city" error)
4. Start the server: `python app.py`

### 2. Mobile App Connection Setup
To fix the `Connection refused` (localhost) error, the app needs your computer's IP address.

1. **Find your IP**: Open Terminal and run `ipconfig`. Look for the **IPv4 Address** (e.g., `192.168.1.XX`).
2. **Run with your IP**: Use this command to run the app:
   ```bash
   flutter run --dart-define=API_URL=http://your_ip:5000/api
   ```
   *Replace `your_ip` with your actual IPv4 address.*

---

## 🛠️ Key Files
- **Backend API**: [app.py](file:///c:/Users/janan/Downloads/Safe-Her-travel/backend/app.py)
- **Database Schema**: [setup_database.py](file:///c:/Users/janan/Downloads/Safe-Her-travel/backend/setup_database.py)
- **Mobile API Logic**: [api_service.dart](file:///c:/Users/janan/Downloads/Safe-Her-travel/mobile/lib/services/api_service.dart)
