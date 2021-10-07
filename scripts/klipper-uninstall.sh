#!/bin/bash
# Uninstall script for raspbian/debian type installations

# Stop Klipper Service
echo "#### Stopping Klipper Service.."
sudo systemctl stop klipper

# Remove Klipper from Startup
echo
echo "#### Removing Klipper from Startup.."
sudo update-rc.d -f klipper remove
sudo systemctl disable klipper

# Remove Klipper from Services
echo
echo "#### Removing Klipper Service.."
sudo rm -f /etc/init.d/klipper /etc/default/klipper
sudo rm -f /etc/systemd/system/klipper.service
sudo rm -f /tmp/klippy_uds
sudo rm -f /tmp/printer

# Notify user of method to remove Klipper source code
echo
echo "The Klipper system files have been removed."
echo
echo "The following command is typically used to remove local files:"
echo "  rm -rf ~/klippy-env ~/klipper"
