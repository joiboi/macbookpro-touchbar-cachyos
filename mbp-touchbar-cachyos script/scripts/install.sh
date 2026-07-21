#!/usr/bin/env bash
set -e

echo "========================================"
echo "  MacBook Pro Touch Bar Installer"
echo "  for CachyOS"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh"
    exit 1
fi

# 1. Install dependencies
echo "[1/7] Installing dependencies..."
pacman -S --needed --noconfirm git dkms base-devel linux-cachyos-headers 2>/dev/null || true

# 2. Install driver
echo "[2/7] Installing Touch Bar driver..."
if [ ! -d "/usr/src/applespi-0.1" ]; then
    git clone https://github.com/Heratiki/macbook12-spi-driver.git /usr/src/applespi-0.1
fi
dkms add applespi/0.1 2>/dev/null || true
dkms install applespi/0.1 --force

# 3. Configure module parameters
echo "[3/7] Configuring module parameters..."
cp modprobe-config/apple-touchbar.conf /etc/modprobe.d/apple-touchbar.conf

# 4. Add modules to initramfs
echo "[4/7] Updating initramfs..."
if ! grep -q "apple_ibridge" /etc/mkinitcpio.conf; then
    sed -i 's/MODULES=(/MODULES=(applespi intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb apple_ib_als /' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# 5. Remove broken udev rule
echo "[5/7] Fixing udev rules..."
rm -f /etc/udev/rules.d/99-mbp-t1-touchbar.rules
cp udev-rules/99-apple-touchbar.rules /etc/udev/rules.d/99-apple-touchbar.rules
cp udev-rules/50-apple-ibridge-power.rules /etc/udev/rules.d/50-apple-ibridge-power.rules
udevadm control --reload-rules

# 6. Disable bind service
systemctl disable mbp-t1-touchbar-bind.service 2>/dev/null || true
systemctl stop mbp-t1-touchbar-bind.service 2>/dev/null || true

# 7. Done
echo ""
echo "========================================"
echo "  Installation Complete!"
echo "========================================"
echo ""
echo "Please reboot to activate the Touch Bar."
echo ""
echo "After reboot, the Touch Bar should display"
echo "function keys (F1-F12)."
echo ""
