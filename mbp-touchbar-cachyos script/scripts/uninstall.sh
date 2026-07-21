#!/usr/bin/env bash
set -e

echo "========================================"
echo "  MacBook Pro Touch Bar Uninstaller"
echo "========================================"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./uninstall.sh"
    exit 1
fi

echo "[1/5] Removing DKMS module..."
dkms remove applespi/0.1 --all 2>/dev/null || true
rm -rf /usr/src/applespi-0.1

echo "[2/5] Removing config files..."
rm -f /etc/modprobe.d/apple-touchbar.conf
rm -f /etc/udev/rules.d/99-apple-touchbar.rules
rm -f /etc/udev/rules.d/50-apple-ibridge-power.rules
rm -f /etc/udev/rules.d/99-mbp-t1-touchbar.rules

echo "[3/5] Restoring initramfs..."
sed -i 's/MODULES=(applespi intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb apple_ib_als /MODULES=(/' /etc/mkinitcpio.conf 2>/dev/null || true
mkinitcpio -P

echo "[4/5] Reloading udev..."
udevadm control --reload-rules

echo "[5/5] Done!"
echo ""
echo "Touch Bar driver has been removed."
echo "Reboot to complete uninstallation."
