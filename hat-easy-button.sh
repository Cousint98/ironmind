#!/bin/bash
# ============================================
# C & C Pi Firm - HAT Easy Button
# One script to rule them all
# Power Management HAT (B) full setup for Pi 5
# ============================================

set -e

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "Run this with sudo: sudo ./hat-easy-button.sh"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-pi}"
ACTUAL_HOME="/home/$ACTUAL_USER"

echo ""
echo "================================================"
echo "  C & C Pi Firm - HAT Easy Button"
echo "  Installing for user: $ACTUAL_USER"
echo "  Home directory: $ACTUAL_HOME"
echo "================================================"
echo ""

# ---- PHASE 1: Dependencies ----
echo "===== PHASE 1: Dependencies ====="
echo "[1/7] Installing system packages..."
apt update -qq
apt install -y \
    automake autoconf build-essential texinfo \
    libtool libftdi-dev libusb-1.0-0-dev \
    libgpiod-dev libgpiod3 gpiod \
    python3-rpi-lgpio python3-serial \
    cmake gcc-arm-none-eabi libnewlib-arm-none-eabi \
    git wget
echo "  Packages installed."
echo ""

# ---- PHASE 2: Enable UART ----
echo "===== PHASE 2: UART Setup ====="
echo "[2/7] Enabling UART..."
CONFIG="/boot/firmware/config.txt"
if grep -q "^#dtparam=uart0" "$CONFIG" 2>/dev/null; then
    sed -i 's/^#dtparam=uart0/dtparam=uart0/' "$CONFIG"
    echo "  UART uncommented in config.txt"
elif grep -q "^dtparam=uart0" "$CONFIG" 2>/dev/null; then
    echo "  UART already enabled."
else
    echo "dtparam=uart0" >> "$CONFIG"
    echo "  UART added to config.txt"
fi

# Also make sure SPI is enabled (for display later)
if grep -q "^#dtparam=spi=on" "$CONFIG" 2>/dev/null; then
    sed -i 's/^#dtparam=spi=on/dtparam=spi=on/' "$CONFIG"
    echo "  SPI uncommented in config.txt"
elif grep -q "^dtparam=spi=on" "$CONFIG" 2>/dev/null; then
    echo "  SPI already enabled."
else
    echo "dtparam=spi=on" >> "$CONFIG"
    echo "  SPI added to config.txt"
fi
echo ""

# ---- PHASE 3: OpenOCD Config ----
echo "===== PHASE 3: OpenOCD ====="
echo "[3/7] Configuring OpenOCD..."
OPENOCD_CFG="/usr/local/share/openocd/scripts/interface/raspberrypi-swd.cfg"
mkdir -p "$(dirname "$OPENOCD_CFG")"
cat > "$OPENOCD_CFG" << 'EOF'
adapter driver linuxgpiod
adapter gpio swclk 25 -chip 4
adapter gpio swdio 24 -chip 4
adapter speed 5000
EOF
echo "  OpenOCD config written."
echo ""

# ---- PHASE 4: Pico SDK ----
echo "===== PHASE 4: Pico SDK ====="
echo "[4/7] Installing Pico SDK..."
if [ -d "$ACTUAL_HOME/pico/pico-sdk" ]; then
    echo "  Pico SDK already exists, updating..."
    cd "$ACTUAL_HOME/pico/pico-sdk"
    sudo -u "$ACTUAL_USER" git pull --quiet
    sudo -u "$ACTUAL_USER" git submodule update --init --quiet
else
    mkdir -p "$ACTUAL_HOME/pico"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/pico"
    cd "$ACTUAL_HOME/pico"
    sudo -u "$ACTUAL_USER" git clone --quiet https://github.com/raspberrypi/pico-sdk.git
    cd pico-sdk
    sudo -u "$ACTUAL_USER" git submodule update --init --quiet
fi
echo "  Pico SDK ready at $ACTUAL_HOME/pico/pico-sdk"
echo ""

# ---- PHASE 5: Build Firmware (Button_Ctr mode) ----
echo "===== PHASE 5: Firmware Build ====="
echo "[5/7] Building Power Management HAT firmware..."
if [ -d "$ACTUAL_HOME/Power-example" ]; then
    echo "  Power-example already exists, cleaning..."
    rm -rf "$ACTUAL_HOME/Power-example/build"
else
    cd "$ACTUAL_HOME"
    sudo -u "$ACTUAL_USER" git clone --quiet https://github.com/waveshare/Power-Management-HAT.git "$ACTUAL_HOME/Power-example-temp"
    # The repo has the examples in a subfolder - grab what we need
    if [ -d "$ACTUAL_HOME/Power-example-temp/Power-example" ]; then
        sudo -u "$ACTUAL_USER" mv "$ACTUAL_HOME/Power-example-temp/Power-example" "$ACTUAL_HOME/Power-example"
        rm -rf "$ACTUAL_HOME/Power-example-temp"
    else
        sudo -u "$ACTUAL_USER" mv "$ACTUAL_HOME/Power-example-temp" "$ACTUAL_HOME/Power-example"
    fi
fi

# Fix CMakeLists.txt to use Button_Ctr (not Period_Time!)
CMAKELISTS="$ACTUAL_HOME/Power-example/CMakeLists.txt"
if [ -f "$CMAKELISTS" ]; then
    # Replace whatever example source is set to use Button_Ctr
    sed -i 's|set(DIR_examples_SRCS.*)|set(DIR_examples_SRCS ./Button_Ctr.c)|' "$CMAKELISTS"
    echo "  CMakeLists.txt set to Button_Ctr mode."
fi

# Build
mkdir -p "$ACTUAL_HOME/Power-example/build"
cd "$ACTUAL_HOME/Power-example/build"
export PICO_SDK_PATH="$ACTUAL_HOME/pico/pico-sdk"
cmake .. -DPICO_SDK_PATH="$ACTUAL_HOME/pico/pico-sdk" 2>&1 | tail -3
make -j$(nproc) 2>&1 | tail -5
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/Power-example"

if [ -f "$ACTUAL_HOME/Power-example/build/Power_Management_HAT.uf2" ]; then
    echo "  Firmware built successfully!"
    echo "  File: $ACTUAL_HOME/Power-example/build/Power_Management_HAT.uf2"
else
    echo "  WARNING: Firmware .uf2 not found. Build may have failed."
fi
echo ""

# ---- PHASE 6: StatusDetection Service ----
echo "===== PHASE 6: StatusDetection Service ====="
echo "[6/7] Setting up StatusDetection service..."
mkdir -p "$ACTUAL_HOME/bin/PowerManagementHAT"
wget -q https://raw.githubusercontent.com/Cousint98/ironmind/main/StatusDetection.py \
    -O "$ACTUAL_HOME/bin/PowerManagementHAT/StatusDetection.py"
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/bin/PowerManagementHAT"

cat > /etc/systemd/system/power-management-hat.service << EOF
[Unit]
Description=Power Management HAT Status Detection
After=basic.target

[Service]
ExecStart=/usr/bin/python3 $ACTUAL_HOME/bin/PowerManagementHAT/StatusDetection.py
WorkingDirectory=$ACTUAL_HOME
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable power-management-hat.service
systemctl start power-management-hat.service
echo "  Service enabled and started."
echo ""

# ---- PHASE 7: Dashboard ----
echo "===== PHASE 7: Dashboard ====="
echo "[7/7] Installing dashboard..."
if [ -f "$ACTUAL_HOME/pi_dashboard.py" ]; then
    echo "  Dashboard already exists at $ACTUAL_HOME/pi_dashboard.py"
else
    echo "  Dashboard will be SCP'd separately."
fi

# Add dashboard alias to bashrc
BASHRC="$ACTUAL_HOME/.bashrc"
if ! grep -q "alias dashboard=" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# C & C Pi Firm Dashboard" >> "$BASHRC"
    echo "alias dashboard='sudo python3 ~/pi_dashboard.py'" >> "$BASHRC"
    echo "  Dashboard alias added to .bashrc"
else
    echo "  Dashboard alias already exists."
fi
echo ""

# ---- DONE ----
echo "================================================"
echo "  SETUP COMPLETE!"
echo "================================================"
echo ""
echo "  Service status:"
systemctl status power-management-hat.service --no-pager || true
echo ""
echo "================================================"
echo "  NEXT STEPS:"
echo "================================================"
echo ""
echo "  1. FLASH THE FIRMWARE (requires physical access):"
echo "     - Hold BOOT button on the HAT"
echo "     - While holding BOOT, tap the RST button"
echo "     - Release BOOT — HAT mounts as RPI-RP2"
echo "     - Run: sudo cp ~/Power-example/build/Power_Management_HAT.uf2 /media/$ACTUAL_USER/RPI-RP2/"
echo ""
echo "  2. REBOOT:"
echo "     sudo reboot"
echo ""
echo "  3. AFTER REBOOT, verify:"
echo "     sudo systemctl status power-management-hat.service"
echo "     dashboard"
echo ""
echo "  HAT power button: press ~1 sec to toggle on/off"
echo "  Battery ~3.5V = ~20%, plug in before 3.0V"
echo "================================================"
