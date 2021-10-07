#!/bin/bash
# Uninstall script for raspbian/debian type installations

stop_service(){
    # Stop Klipper Service
    echo "#### Stopping Klipper Service.."
    sudo systemctl stop klipper
}

remove_service(){
    # Remove Klipper from Startup
    echo
    echo "#### Removing Klipper Service.."
    if [ -f "/etc/init.d/klipper" ]; then
        # legacy installation, remove the LSB service
        sudo update-rc.d -f klipper remove
        sudo rm -f /etc/init.d/klipper
        sudo rm -f /etc/default/klipper
    else
        sudo systemctl disable klipper
        sudo rm -f /etc/systemd/system/klipper.service
        sudo systemctl daemon-reload
        sudo systemctl reset-failed
    fi
}

remove_files(){
    # Remove Klipper Unix Domain Socket
    if [ -e /tmp/klippy_uds ]; then
        echo "#### Removing Unix Domain Socket.."
        sudo rm -f /tmp/klippy_uds
    fi

    # Remove the virtual serial port
    if [ -h /tmp/printer ]; then
        echo "#### Removing virtual serial port.."
        sudo rm -f /tmp/printer
    fi

    # Remove the virtualenv
    if [ -d ~/klippy-env ]; then
        echo "#### Removing virtualenv..."
        rm -rf ~/klippy-env
    fi

    # Notify user of method to remove Klipper source code
    echo
    echo "The Klipper system files and virtualenv have been removed."
    echo
    echo "The following command is typically used to remove source files:"
    echo "  rm -rf ~/klipper"
}

verify_ready()
{
    if [ "$EUID" -eq 0 ]; then
        echo "This script must not run as root"
        exit -1
    fi
}

verify_ready
stop_service
remove_service
remove_files