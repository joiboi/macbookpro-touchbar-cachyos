# MacBook Pro 14,2 (2017) Touch Bar for CachyOS

One-command installer to get the Touch Bar working on MacBook Pro 14,2 (2017) with T1 chip running CachyOS.

## Quick Start

```bash
git clone https://github.com/joiboi/mbp-touchbar-cachyos.git
cd mbp-touchbar-cachyos
sudo ./scripts/install.sh
sudo reboot
```

## What This Fixes
| Problem                               | Cause                           | Fix                                   |
| ------------------------------------- | ------------------------------- | ------------------------------------- |
| Display turns on then off during boot | Udev rebind rule resets T1 chip | Remove `99-mbp-t1-touchbar.rules`     |
| Display never turns on                | Wrong driver fork               | Use Heratiki's `macbook12-spi-driver` |
| Display turns off after idle          | Default timeout                 | Set `idle_timeout=-1`                 |

## Tested On

- **MacBook Pro 14,2 (2017)** — CachyOS 7.1.3
- **MacBook Pro 14,3 (2017)** — CachyOS 7.1.3

## Credits

- **[Heratiki](https://github.com/Heratiki/macbook12-spi-driver)** — Fixed driver fork
- **[Ronald Tschalär](https://github.com/roadrunner2/macbook12-spi-driver)** — Original author


### `scripts/install.sh`
```bash
#!/usr/bin/env bash
set -e

echo "MacBook Pro Touch Bar Installer for CachyOS"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh"
    exit 1
fi

# Install dependencies
pacman -S --needed --noconfirm git dkms base-devel linux-cachyos-headers 2>/dev/null || true

# Install driver
if [ ! -d "/usr/src/applespi-0.1" ]; then
    git clone https://github.com/Heratiki/macbook12-spi-driver.git /usr/src/applespi-0.1
fi
dkms add applespi/0.1 2>/dev/null || true
dkms install applespi/0.1 --force

# Configure parameters
echo 'options apple_ib_tb idle_timeout=-1 dim_timeout=-1 fnmode=1' > /etc/modprobe.d/apple-touchbar.conf

# Update initramfs
if ! grep -q "apple_ibridge" /etc/mkinitcpio.conf; then
    sed -i 's/MODULES=(/MODULES=(applespi intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb apple_ib_als /' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# Fix udev rules
rm -f /etc/udev/rules.d/99-mbp-t1-touchbar.rules
cp udev-rules/99-apple-touchbar.rules /etc/udev/rules.d/
cp udev-rules/50-apple-ibridge-power.rules /etc/udev/rules.d/
udevadm control --reload-rules

# Disable bind service
systemctl disable mbp-t1-touchbar-bind.service 2>/dev/null || true

echo ""
echo "Done! Please reboot to activate the Touch Bar."
