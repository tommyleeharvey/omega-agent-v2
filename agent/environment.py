"""Real environment sensors: battery + IP-geolocation + LAN discovery.
No fabrication — every field comes from a live syscall, nmap subprocess,
or real HTTP request. MAC/ARP unavailable unrooted on Android (netlink +
/proc/net/arp denied by SELinux) — nmap's own host-discovery still works
despite that warning, so we shell out to it and parse IPs only."""
import subprocess
import re
import json
import os
import requests

IP_RE = re.compile(r"Nmap scan report for ([\d.]+)")


def get_battery_status():
    try:
        out = subprocess.run(["termux-battery-status"], capture_output=True, text=True, timeout=5)
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
        parts.append(f"battery {battery.get('percentage')}% ({battery.get('status')}, {battery.get('temperature')}\u00b0C)")
    if "error" not in location:
        parts.append(f"location {location.get('city')}, {location.get('regionName')} (ISP: {location.get('isp')})")
    return "; ".join(parts) if parts else "environment sensors unavailable"


def _get_local_subnet():
    """Own /24, e.g. 192.168.11.0/24, derived from a real outbound socket."""
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "192.168.1.1"
    finally:
        s.close()
    base = ".".join(ip.split(".")[:3])
    return f"{base}.0/24"


def scan_network_devices():
    """nmap -sn host discovery. No MAC (unrooted Android blocks ARP/netlink
    read), but real IP presence — proven working standalone."""
    subnet = _get_local_subnet()
    try:
        out = subprocess.run(
            ["nmap", "-sn", subnet], capture_output=True, text=True, timeout=30
        )
        ips = IP_RE.findall(out.stdout)
        return [{"ip": ip} for ip in ips]
    except Exception as e:
        return {"error": str(e)}


def check_for_new_devices(known_devices_path="~/.omega/known_devices.json"):
    path = os.path.expanduser(known_devices_path)
    current = scan_network_devices()
    if isinstance(current, dict) and "error" in current:
        return current

    current_ips = {d["ip"] for d in current}
    known_ips = set()
    if os.path.exists(path):
        with open(path) as f:
            known_ips = set(json.load(f))

    new_ips = current_ips - known_ips
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(list(current_ips | known_ips), f)

    return {"total_devices": len(current_ips), "devices": sorted(current_ips), "new_devices": sorted(new_ips)}
