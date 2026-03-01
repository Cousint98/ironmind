#!/usr/bin/env python3
"""
C & C Pi Firm - System Dashboard
Displays HAT battery/power data + system stats
Designed for 3.5" 480x320 display
"""

import serial
import os
import time
import subprocess
import threading

# HAT UART Settings
UART_PORT = "/dev/ttyAMA0"
UART_BAUD = 115200

# Global HAT data
hat_data = {
    "power_state": "---",
    "running_state": "---",
    "vin_voltage": "---",
    "vout_voltage": "---",
    "vout_current": "---",
    "battery_pct": "---",
}


def estimate_battery_pct(vin):
    """Estimate battery % from input voltage"""
    try:
        v = float(vin)
        if v > 4.5:
            return "USB"
        elif v >= 4.2:
            return "100%"
        elif v >= 4.0:
            return "80%"
        elif v >= 3.85:
            return "60%"
        elif v >= 3.7:
            return "40%"
        elif v >= 3.5:
            return "20%"
        elif v >= 3.3:
            return "10%"
        else:
            return "LOW!"
    except:
        return "---"


def get_battery_bar(vin):
    """Visual battery bar"""
    try:
        v = float(vin)
        if v > 4.5:
            return "[==USB==]"
        pct = max(0, min(100, (v - 3.0) / (4.2 - 3.0) * 100))
        filled = int(pct / 10)
        return "[" + "#" * filled + "-" * (10 - filled) + "]"
    except:
        return "[----------]"


def read_hat_uart():
    """Background thread to read HAT data from UART"""
    try:
        ser = serial.Serial(UART_PORT, UART_BAUD, timeout=2)
        buffer = ""
        while True:
            try:
                data = ser.read(ser.in_waiting or 1).decode("utf-8", errors="ignore")
                buffer += data
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if "Power_State" in line and ":" in line:
                        val = line.split(":")[-1].strip()
                        hat_data["power_state"] = "ON" if val == "1" else "OFF"
                    elif "Running_State" in line and ":" in line:
                        val = line.split(":")[-1].strip()
                        hat_data["running_state"] = "ON" if val == "1" else "OFF"
                    elif "Vin_Voltage" in line and ":" in line:
                        val = line.split(":")[-1].strip()
                        hat_data["vin_voltage"] = val
                        hat_data["battery_pct"] = estimate_battery_pct(val)
                    elif "Vout_Voltage" in line and ":" in line:
                        hat_data["vout_voltage"] = line.split(":")[-1].strip()
                    elif "Vout_Current" in line and ":" in line:
                        hat_data["vout_current"] = line.split(":")[-1].strip()
            except:
                time.sleep(0.5)
    except Exception as e:
        hat_data["power_state"] = f"ERR: {e}"


def get_cpu_temp():
    try:
        temp = open("/sys/class/thermal/thermal_zone0/temp").read().strip()
        return f"{int(temp) / 1000:.1f}C"
    except:
        return "---"


def get_cpu_usage():
    try:
        result = subprocess.run(
            ["grep", "cpu ", "/proc/stat"],
            capture_output=True, text=True
        )
        parts = result.stdout.split()
        idle = int(parts[4])
        total = sum(int(x) for x in parts[1:])
        time.sleep(0.1)
        result2 = subprocess.run(
            ["grep", "cpu ", "/proc/stat"],
            capture_output=True, text=True
        )
        parts2 = result2.stdout.split()
        idle2 = int(parts2[4])
        total2 = sum(int(x) for x in parts2[1:])
        usage = (1 - (idle2 - idle) / (total2 - total)) * 100
        return f"{usage:.0f}%"
    except:
        return "---"


def get_ram_usage():
    try:
        result = subprocess.run(
            ["free", "-m"], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        parts = lines[1].split()
        total = int(parts[1])
        used = int(parts[2])
        pct = (used / total) * 100
        return f"{used}M/{total}M ({pct:.0f}%)"
    except:
        return "---"


def get_disk_usage():
    try:
        result = subprocess.run(
            ["df", "-h", "/"], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        parts = lines[1].split()
        return f"{parts[2]}/{parts[1]} ({parts[4]})"
    except:
        return "---"


def get_uptime():
    try:
        result = subprocess.run(
            ["uptime", "-p"], capture_output=True, text=True
        )
        return result.stdout.strip().replace("up ", "")
    except:
        return "---"


def get_ip():
    try:
        result = subprocess.run(
            ["hostname", "-I"], capture_output=True, text=True
        )
        ips = result.stdout.strip().split()
        return ips[0] if ips else "---"
    except:
        return "---"


def draw_dashboard():
    """Main dashboard display loop"""
    while True:
        os.system("clear")

        vin = hat_data["vin_voltage"]
        bat_bar = get_battery_bar(vin)
        bat_pct = hat_data["battery_pct"]

        print("=" * 46)
        print("     C & C Pi Firm - System Dashboard")
        print("=" * 46)
        print()
        print(f"  BATTERY  {bat_bar}  {bat_pct}")
        print(f"  Vin: {vin}V   Vout: {hat_data['vout_voltage']}V")
        print(f"  Current: {hat_data['vout_current']} MA")
        print(f"  Power: {hat_data['power_state']}    Pi: {hat_data['running_state']}")
        print()
        print("-" * 46)
        print()
        print(f"  CPU Temp:  {get_cpu_temp()}")
        print(f"  CPU Usage: {get_cpu_usage()}")
        print(f"  RAM:       {get_ram_usage()}")
        print(f"  Disk:      {get_disk_usage()}")
        print(f"  Uptime:    {get_uptime()}")
        print(f"  IP:        {get_ip()}")
        print()
        print("-" * 46)
        print("  Ctrl+C to exit")
        print("=" * 46)

        time.sleep(2)


if __name__ == "__main__":
    # Start HAT reader in background thread
    uart_thread = threading.Thread(target=read_hat_uart, daemon=True)
    uart_thread.start()

    # Give UART a moment to get first reading
    time.sleep(3)

    try:
        draw_dashboard()
    except KeyboardInterrupt:
        print("\nDashboard stopped.")
