#!/bin/bash
# This script installs Klipper on an Arch Linux system

PYTHONDIR="${HOME}/klippy-env"
SYSTEMDDIR="/etc/systemd/system"

# Step 1: Install system packages
install_packages()
{
    # Packages for python cffi
    PKGLIST="libffi base-devel"
    # kconfig requirements
    PKGLIST="${PKGLIST} ncurses"
    # hub-ctrl
    PKGLIST="${PKGLIST} libusb"
    # AVR chip installation and building
    PKGLIST="${PKGLIST} avrdude avr-gcc avr-binutils avr-libc"
    # ARM chip installation and building
    AURLIST="stm32flash"
    PKGLIST="${PKGLIST} arm-none-eabi-newlib"
    PKGLIST="${PKGLIST} arm-none-eabi-gcc arm-none-eabi-binutils"

    # Install desired packages
     report_status "Installing packages..."
     sudo pacman -S ${PKGLIST}
    # Clone source from AUR and build install package
    report_status "Building required packages..."
    cd ${HOME} && git clone https://aur.archlinux.org/${AURLIST}.git
    cd ${AURLIST} && makepkg
    report_status "Installing packages..."
    sudo pacman -U *.pkg.tar.zst --noconfirm
    report_status "Removing directories that are no longer needed..."
    cd ${HOME} && rm -rf ${AURLIST}
}

# Step 2: Create python virtual environment
create_virtualenv()
{
    report_status "Updating python virtual environment..."

    # Create virtualenv if it doesn't already exist
    [ ! -d ${PYTHONDIR} ] && python -m venv ${PYTHONDIR}

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
Environment=KLIPPER=${SRCDIR}/klippy/klippy.py
Environment=KLIPPER_CONFIG=${HOME}/klipper_config/printer.cfg
Environment=KLIPPER_LOGS=${HOME}/klipper_logs/klippy.log
Environment=KLIPPER_PRINTER=/tmp/printer
Environment=KLIPPER_SOCKET=/tmp/klippy_uds

Type=simple
User=$USER
ExecStart=${PYTHONDIR}/bin/python \${KLIPPER} \${KLIPPER_CONFIG} -l \${KLIPPER_LOGS} -I \${KLIPPER_PRINTER} -a \${KLIPPER_SOCKET}

Restart=always
RestartSec=10
EOF
# Use systemctl to enable the klipper systemd service script
    sudo systemctl enable klipper.service
    report_status "Make sure to add $KLIPPER_USER to the user group controlling your serial printer port"
}

# Step 4: Start host software
start_software()
{
    report_status "Launching Klipper host software..."
    sudo systemctl start klipper
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

# Force script to exit if an error occurs
set -e

# Find SRCDIR from the pathname of this script
SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"

# Run installation steps defined above
verify_ready
install_packages
create_virtualenv
install_script
start_software
