#!/bin/bash
# This script installs Klipper on an debian
#

# Force script to exit if an error occurs
set -e

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

# Default file paths
SYSTEMDDIR="/etc/systemd/system"
PYTHONDIR="${HOME}/klippy-env"
PYTHONEXEC="${PYTHONDIR}/bin/python"
KLIPPER_PATH="${SRCDIR}/klippy/klippy.py"
CONFIG_PATH="${HOME}/klipper_config/printer.cfg"
LOG_PATH="${HOME}/klipper_logs/klippy.log"
PRINTER_PATH="/tmp/printer"
UDS_PATH="/tmp/klippy_uds"

# Step 1: Install system packages
install_packages()
{
    # Packages for python cffi
    PKGLIST="python3-virtualenv python3-dev libffi-dev build-essential"
    # kconfig requirements
    PKGLIST="${PKGLIST} libncurses-dev"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb-dev"
    # AVR chip installation and building
    PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
    # ARM chip installation and building
    PKGLIST="${PKGLIST} stm32flash libnewlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0"

    # Update system package info
    report_status "Running apt-get update..."
    sudo apt-get update --allow-releaseinfo-change

    # Install desired packages
    report_status "Installing packages..."
    sudo apt-get install --yes ${PKGLIST}
}

# Step 2: Create python virtual environment
create_virtualenv()
{
    report_status "Updating python virtual environment..."

    # Create virtualenv if it doesn't already exist
    [ ! -d ${PYTHONDIR} ] && virtualenv -p python3 ${PYTHONDIR}

    # Install/update dependencies
    ${PYTHONDIR}/bin/pip install -r ${SRCDIR}/scripts/klippy-requirements.txt
}

# Step 3: Install startup script
install_script()
{
# Create systemd service file
    report_status "Installing system start script..."

    [ ! -d "${HOME}/klipper_logs" ] && mkdir "${HOME}/klipper_logs"
    [ ! -d "${HOME}/klipper_config" ] && mkdir "${HOME}/klipper_config"

    sudo /bin/sh -c "cat > $SYSTEMDDIR/klipper.service" << EOF
#Systemd service file for klipper
[Unit]
Description=Starts Klipper and provides a Unix Domain Socket API
Documentation=https://www.klipper3d.org/
Before=moonraker.service
After=network.target
Wants=udev.target

[Install]
WantedBy=multi-user.target

[Service]
Environment=KLIPPER=${KLIPPER_PATH}
Environment=KLIPPER_CONFIG=${CONFIG_PATH}
Environment=KLIPPER_LOGS=${LOG_PATH}
Environment=KLIPPER_PRINTER=${PRINTER_PATH}
Environment=KLIPPER_SOCKET=${UDS_PATH}

Type=simple
User=$USER
ExecStart=${PYTHONEXEC} \${KLIPPER} \${KLIPPER_CONFIG} -l \${KLIPPER_LOGS} -I \${KLIPPER_PRINTER} -a \${KLIPPER_SOCKET}

Restart=always
RestartSec=10
EOF
# Use systemctl to enable the klipper systemd service script
    sudo systemctl enable klipper.service
    sudo systemctl daemon-reload
}

# Step 4: Start host software
start_software()
{
    report_status "Launching Klipper host software..."
    sudo systemctl start klipper.service
}

# Helper functions
report_status()
{
    echo -e "\n\n###### $1"
}

verify_ready()
{
    if [ "$EUID" -eq 0 ]; then
        echo "This script must not run as root"
        exit -1
    fi
}

# Run installation steps defined above
verify_ready
install_packages
create_virtualenv
install_script
start_software