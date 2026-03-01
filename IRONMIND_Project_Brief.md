# PROJECT IRONMIND — FORGE's Cyberdeck

## Agent
- **Codename**: FORGE (Holden)
- **Role**: Builder/Engineer archetype — "If TINKER fixes what's broken, FORGE builds what doesn't exist yet"
- **Project**: IRONMIND Field Station Mk.1

## Hardware
- **Pi 5**: Main brain, NVMe via PiNorMOMI bottom mount, Waveshare Power HAT B on GPIO
- **Pi Zero W**: DigiPi Amp audio node, 3.5" SPI #2 for media/gaming
- **ESP32 WROOM**: Home automation sensor/display node (needs LoRa add-on for Meshtastic)
- **7.5" HDMI**: Pi 5 main desktop
- **3.5" SPI #1**: Pi 5 dedicated CLI terminal
- **2.8" TFT #1**: Pi 5 performance dashboard (pi_dashboard.py extended)
- **2.8" TFT #2**: ESP32 home automation HUD
- **3.5" SPI #2**: Pi Zero W media display
- **Logitech POP**: Multi-device keyboard/mouse (3-device pairing — Pi5, PiZero, spare)
- **2x 126090 8000mAh LiPo**: JST PH 2.54 — wire in parallel for 16Ah/~53Wh usable
- **Joystick**: Pi Zero W gaming + Pi 5 robot arm control

## Key Hardware Still Needed
- NVMe SSD: **M.2 2230 form factor** (WD SN730 or Samsung PM991 128GB) ~$30
- Powered USB Hub: Sabrent HB-UMP3 ~$20
- TTGO T-Beam v1.2 (replaces bare ESP32 WROOM — adds LoRa + GPS) ~$30
- RTL-SDR Blog V4 (HAM radio / SDR) ~$38
- DRV8825 stepper driver modules x2 ~$10
- Noctua NF-A4x10 5V fan (Pi 5 heat under Ollama load) ~$18
- JST PH 2.54 → XT30 adapter for battery (current capacity) ~$8

## HAT Stacking Gotcha
- PiNorMOMI = bottom mount (PCIe M.2) — no GPIO conflict ✓
- Power HAT B = on GPIO header — check if it has passthrough pins
- SPI displays CANNOT share GPIO header if HAT has no passthrough
- Fix: use GPIO ribbon extension OR USB-connected display variants
- UART on ttyAMA0 already working (pi_dashboard.py confirmed)

## Software Install Order
1. Pi OS 64-bit + Pi OS Lite (Zero W) + SSH setup
2. Power HAT B (hat-easy-button.sh already written)
3. Pi-hole
4. Ollama (already running — enable on boot)
5. DigiPi Amp on Pi Zero W
6. SPI display drivers
7. Home Assistant (Docker)
8. hostapd WiFi AP (IRONMIND-AP, 192.168.50.x)
9. VS Code Server + Arduino IDE + Git
10. RTL-SDR + GQRX
11. RetroPie/Retroarch on Pi Zero W
12. FreeCAD + OpenSCAD
13. Meshtastic on T-Beam
14. Tailscale VPN

## Key Software Running
- Ollama: port 8080 (already running on Pi 5)
- Home Assistant: port 8123 (Docker)
- Pi-hole: port 80/admin
- Trading Desk: port 5001

## Battery Runtime
- Dual 126090 in parallel: ~16Ah / ~53Wh usable
- Tournament realistic use: 6-7 hours
- Full load (Ollama): 4-5 hours

## Tournament Deployment (Off-Grid Mode)
- Pi 5 runs IRONMIND-AP WiFi hotspot for friends (Pi-hole DNS = no ads for everyone)
- All services local — no internet required
- Meshtastic for off-grid comms between team

## Educational Projects (Priority Order)
1. Power telemetry dashboard (Python + SQLite + Flask)
2. Meshtastic mesh network
3. Lookout camera system port
4. Home automation with ESP32 + MQTT
5. Ollama AI coding assistant CLI
6. RTL-SDR signals station (ADS-B flight tracking, AM radio, weather sats)
7. Stellarium sky map (stargazing — Phase 3, no extra hardware needed)
7. Stepper motor robot controller
8. FCC Technician License exam

## Files to Reference
- `hat-easy-button.sh` — Power HAT B setup (extend for IRONMIND)
- `pi_dashboard.py` — Dashboard base (extend with Ollama status, AP clients)
- `the_lookout/agents/` — Agent patterns to port
- `SOP_Field_Manual.md` — Doc style template
