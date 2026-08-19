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


def scan_network_devices():
    """Real ARP-table scan of the local network — actual devices, not guesses."""
    import subprocess
    try:
        subprocess.run(
            ["nmap", "-sn", "192.168.11.0/24"], capture_output=True, text=True, timeout=30
        )
        arp = subprocess.run(["cat", "/proc/net/arp"], capture_output=True, text=True, timeout=5)
        devices = []
        for line in arp.stdout.strip().split("\n")[1:]:
            fields = line.split()
            if len(fields) >= 4 and fields[3] != "00:00:00:00:00:00":
                devices.append({"ip": fields[0], "mac": fields[3]})
        return devices
    except Exception as e:
        return {"error": str(e)}


def check_for_new_devices(known_devices_path="~/.omega/known_devices.json"):
    """Compares current scan against a saved baseline. Returns any new MACs."""
    import os, json
    path = os.path.expanduser(known_devices_path)
    current = scan_network_devices()
    if isinstance(current, dict) and "error" in current:
        return current

    current_macs = {d["mac"] for d in current}
    known_macs = set()
    if os.path.exists(path):
        with open(path) as f:
            known_macs = set(json.load(f))

    new_macs = current_macs - known_macs
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(list(current_macs | known_macs), f)

    return {"total_devices": len(current_macs), "new_devices": list(new_macs)}
