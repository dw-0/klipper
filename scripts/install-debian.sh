#!/bin/bash
# This script installs Klipper on debian based distros like
# - Raspberry Pi OS
# - OctoPi 0.18.0
# - Debian Buster
# - Ubuntu 20

# Force script to exit if an error occurs
set -e

REBUILD_ENV="n"
FORCE_DEFAULTS="n"

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

# Default file paths
SYSTEMDDIR="/etc/systemd/system"
PYTHONDIR="${HOME}/klippy-env"
PYTHONEXEC="${PYTHONDIR}/bin/python"
KLIPPY_PATH="${SRCDIR}/klippy/klippy.py"
CONFIG_PATH="${HOME}/klipper_config/printer.cfg"
LOG_PATH="${HOME}/klipper_logs/klippy.log"
PRINTER_PATH="/tmp/printer"
UDS_PATH="/tmp/klippy_uds"

# Step 1: cleanup legacy installation
cleanup_legacy(){
    if [ -f "/etc/init.d/klipper" ]; then
        echo "#### Cleanup legacy install script"
        sudo syctemctl stop klipper
        sudo update-rc.d -f klipper remove
        sudo rm -f /etc/init.d/klipper
        sudo rm -f /etc/default/klipper
    fi
}

# Step 2: Install system packages
install_packages()
{
    # Packages for python cffi
    PKGLIST="virtualenv python3-dev libffi-dev build-essential"
    # kconfig requirements
    PKGLIST="${PKGLIST} libncurses-dev"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb-dev"
    # AVR chip installation and building
    PKGLIST="${PKGLIST} avrdude gcc-avr binutils-avr avr-libc"
    # ARM chip installation and building
    PKGLIST="${PKGLIST} stm32flash dfu-util libnewlib-arm-none-eabi"
    PKGLIST="${PKGLIST} gcc-arm-none-eabi binutils-arm-none-eabi libusb-1.0"

    # Update system package info
    report_status "Running apt-get update..."
    sudo apt-get update --allow-releaseinfo-change

    # Install desired packages
    report_status "Installing packages..."
    sudo apt-get install --yes ${PKGLIST}
}

# Step 3: Create python virtual environment
create_virtualenv()
{
    report_status "Updating python virtual environment..."

    # If venv exists and user prompts a rebuild, then do so
    if [ -d ${PYTHONDIR} ] && [ $REBUILD_ENV = "y" ]; then
        report_status "Removing old virtualenv"
        rm -rf ${PYTHONDIR}
    fi

    [ ! -d ${PYTHONDIR} ] && virtualenv -p python3 ${PYTHONDIR}

    # Install/update dependencies
    ${PYTHONDIR}/bin/pip install -r ${SRCDIR}/scripts/klippy-requirements.txt
}

# Step 4: Install startup script
install_script()
{
# Create systemd service file
    report_status "Installing system start script..."

    [ ! -d "${HOME}/klipper_logs" ] && mkdir "${HOME}/klipper_logs"
    [ ! -d "${HOME}/klipper_config" ] && mkdir "${HOME}/klipper_config"

    sudo /bin/sh -c "cat > $SYSTEMDDIR/klipper.service" << EOF
#Systemd service file for Klipper
[Unit]
Description=Starts Klipper and provides a Unix Domain Socket API
Documentation=https://www.klipper3d.org/
Before=moonraker.service
After=network.target
Wants=udev.target

[Install]
WantedBy=multi-user.target

[Service]
Environment=KLIPPY=${KLIPPY_PATH}
Environment=KLIPPER_CONFIG=${CONFIG_PATH}
Environment=KLIPPER_LOGS=${LOG_PATH}
Environment=KLIPPER_PRINTER=${PRINTER_PATH}
Environment=KLIPPER_SOCKET=${UDS_PATH}

Type=simple
User=$USER
ExecStart=${PYTHONEXEC} \${KLIPPY} \${KLIPPER_CONFIG} -l \${KLIPPER_LOGS} -I \${KLIPPER_PRINTER} -a \${KLIPPER_SOCKET}

Restart=always
RestartSec=10
EOF
# Use systemctl to enable the klipper systemd service script
    sudo systemctl enable klipper.service
    sudo systemctl daemon-reload
}

# Step 5: Start host software
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

# Parse command line arguments
while getopts "rfc:l:" arg; do
    case $arg in
        r) REBUILD_ENV="y";;
        f) FORCE_DEFAULTS="y";;
        c) CONFIG_PATH=$OPTARG;;
        l) LOG_PATH=$OPTARG;;
    esac
done

# Run installation steps defined above
verify_ready
cleanup_legacy
install_packages
create_virtualenv
install_script
start_software