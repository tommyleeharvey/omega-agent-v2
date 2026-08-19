"""Real environment sensors: battery + IP-geolocation. No fabrication —
every field here comes from a live system call or HTTP request."""
import subprocess
import json
import requests


def get_battery_status():
    try:
        out = subprocess.run(
            ["termux-battery-status"], capture_output=True, text=True, timeout=5
        )
        return json.loads(out.stdout)
    except Exception as e:
        return {"error": str(e)}


def get_ip_location():
    try:
        r = requests.get("http://ip-api.com/json/", timeout=5)
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def get_environment_context():
    battery = get_battery_status()
    location = get_ip_location()
    parts = []
    if "error" not in battery:
        parts.append(
            f"battery {battery.get('percentage')}% ({battery.get('status')}, "
            f"{battery.get('temperature')}°C)"
        )
    if "error" not in location:
        parts.append(
            f"location {location.get('city')}, {location.get('regionName')} "
            f"(ISP: {location.get('isp')})"
        )
    return "; ".join(parts) if parts else "environment sensors unavailable"
