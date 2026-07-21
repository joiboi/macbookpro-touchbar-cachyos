# MacBook Pro 14,2 (2017) Touch Bar Setup Guide for CachyOS

> **Hardware:** MacBook Pro 14,2 (2017) with T1 chip
> **OS:** CachyOS (Arch-based, kernel 7.1.3+)
> **Goal:** Touch Bar display + input fully working

## My Setup

- **OS:** CachyOS x86_64
- **Host:** MacBook Pro (13-inch, 2017, Four Thunderbolt 3 ports) (1.0)
- **Kernel:** Linux 7.1.3-2-cachyos
- **Shell:** fish 4.8.1
- **DE:** KDE Plasma 6.7.3
- **WM:** KWin (Wayland)
- **WM Theme:** Breeze
- **Theme:** Breeze (Dark) [Qt], Breeze-Dark [GTK2], Breeze [GTK3]
- **Icons:** breeze-dark [Qt], breeze-dark [GTK2/3/4]
- **Font:** Noto Sans (10pt) [Qt], Noto Sans (10pt) [GTK2/3/4]
- **Cursor:** breeze (24px)
- **Terminal:** konsole 26.4.3
- **CPU:** Intel(R) Core(TM) i5-7267U (4) @ 3.50 GHz
- **GPU:** Intel Iris Plus Graphics 650 @ 1.05 GHz [Integrated]
- **Memory:** 4.24 GiB / 7.62 GiB (56%)
- **Swap:** 0 B / 7.62 GiB (0%)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install Base Dependencies](#2-install-base-dependencies)
3. [Install Touch Bar Driver (Heratiki's Fork)](#3-install-touch-bar-driver-heratikis-fork)
4. [Configure Module Parameters](#4-configure-module-parameters)
5. [Fix the Udev Rebind Bug](#5-fix-the-udev-rebind-bug)
6. [Fix USB Autosuspend](#6-fix-usb-autosuspend)
7. [Configure Keyboard Backlight](#7-configure-keyboard-backlight)
8. [Verify Everything Works](#8-verify-everything-works)
9. [Troubleshooting](#9-troubleshooting)
10. [What NOT to Do](#10-what-not-to-do)

---

## 1. Prerequisites

Ensure you have:
- Fresh CachyOS installation
- Internet connection
- `sudo` access
- `git`, `dkms`, `base-devel` installed

```bash
sudo pacman -S git dkms base-devel linux-headers
```

> **Note:** CachyOS uses `linux-cachyos` by default. The headers package is `linux-cachyos-headers`.

---

## 2. Install Base Dependencies

```bash
# Install required packages
sudo pacman -S git dkms base-devel linux-cachyos-headers

# Install additional tools for SPI keyboard/touchpad
sudo pacman -S spi-tools
```

---

## 3. Install Touch Bar Driver (Heratiki's Fork)

**Why Heratiki's fork?** The original `vfontanela/macbookpro14-linux-support` driver has a display initialization bug on modern kernels. Heratiki's fork (`macbook12-spi-driver`) provides `apple-ibridge-hid` which properly handles the T1 Touch Bar on kernel 7.x.

### 3.1 Clone and Install

```bash
# Clone to permanent location (NOT /tmp/)
sudo git clone https://github.com/Heratiki/macbook12-spi-driver.git /usr/src/applespi-0.1

# Set up DKMS
sudo dkms add applespi/0.1
sudo dkms install applespi/0.1
```

### 3.2 Verify Installation

```bash
sudo dkms status | grep applespi
```

Expected output:
```
applespi/0.1, 7.1.3-2-cachyos, x86_64: installed
```

---

## 4. Configure Module Parameters

Create the modprobe configuration file:

```bash
echo 'options apple_ib_tb idle_timeout=-1 dim_timeout=-1 fnmode=1' | sudo tee /etc/modprobe.d/apple-touchbar.conf
```

**Parameter explanations:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `idle_timeout` | `-1` | Display stays ON permanently (never turns off) |
| `dim_timeout` | `-1` | Display never dims |
| `fnmode` | `1` | Fn key switches between special keys and F-keys |

### 4.1 Add Modules to Initramfs

Edit `/etc/mkinitcpio.conf` and add the modules to the `MODULES` array:

```bash
sudo nano /etc/mkinitcpio.conf
```

Find the line:
```
MODULES=()
```

Change to:
```
MODULES=(applespi intel_lpss_pci spi_pxa2xx_platform apple_ibridge apple_ib_tb apple_ib_als)
```

Save and rebuild initramfs:

```bash
sudo mkinitcpio -P
```

---

## 5. Fix the Udev Rebind Bug

**This is the critical fix!** The DKMS package installs a udev rule that triggers a USB rebind during boot. This rebind resets the T1 chip and turns off the Touch Bar display after it has already turned on.

### 5.1 Remove the Broken Udev Rule

```bash
# Check if the rule exists
ls -la /etc/udev/rules.d/99-mbp-t1-touchbar.rules

# Remove it
sudo rm -f /etc/udev/rules.d/99-mbp-t1-touchbar.rules

# Reload udev rules
sudo udevadm control --reload-rules
```

### 5.2 Disable the Bind Service (if it exists)

```bash
sudo systemctl disable mbp-t1-touchbar-bind.service 2>/dev/null || true
sudo systemctl stop mbp-t1-touchbar-bind.service 2>/dev/null || true
```

### 5.3 Keep the Input Permissions Rule

The `99-apple-touchbar.rules` file should remain — it only sets input device permissions:

```bash
# Verify it exists and contains only permissions
cat /etc/udev/rules.d/99-apple-touchbar.rules
```

Expected content:
```
SUBSYSTEM=="input", ATTRS{name}=="*iBridge Virtual HID*", MODE="0664", GROUP="input", TAG+="uaccess"
```

---

## 6. Fix USB Autosuspend

The iBridge USB device may be autosuspended by power management, turning off the Touch Bar.

```bash
# Create udev rule to prevent autosuspend
echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{idProduct}=="8600", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/50-apple-ibridge-power.rules

# Reload udev
sudo udevadm control --reload-rules
```

---

## 7. Configure Keyboard Backlight

The keyboard backlight is controlled via the `applesmc` module and SPI interface.

### 7.1 Ensure applespi Loads

The `applespi` module should already be in your initramfs from Step 4.1. Verify:

```bash
lsmod | grep applespi
```

### 7.2 Keyboard Backlight Brightness

```bash
# Check current brightness
cat /sys/class/leds/spi::kbd_backlight/brightness

# Set brightness (0-255)
echo 100 | sudo tee /sys/class/leds/spi::kbd_backlight/brightness
```

### 7.3 Auto-dim Keyboard Backlight (Optional)

The `apple_ib_als` module provides ambient light sensing. It should auto-dim the keyboard backlight.

---

## 8. Verify Everything Works

### 8.1 Reboot

```bash
sudo reboot
```

### 8.2 After Boot — Visual Check

1. **Look at the Touch Bar** — it should show function keys (F1-F12)
2. **Press Fn key** — it should switch between F-keys and media/app keys
3. **Touch the Touch Bar** — keys should respond

### 8.3 Diagnostic Commands

```bash
# Check kernel
uname -r

# Check loaded modules
lsmod | grep -E "apple|ibridge|hid"

# Check module parameters
cat /sys/module/apple_ib_tb/parameters/idle_timeout
cat /sys/module/apple_ib_tb/parameters/dim_timeout
cat /sys/module/apple_ib_tb/parameters/fnmode

# Check USB device
lsusb | grep -i "iBridge"

# Check input device
grep -H "" /sys/class/input/event*/device/name 2>/dev/null | grep -i "ibridge"

# Test input
sudo evtest /dev/input/eventX  # Replace X with the iBridge device number

# Check dmesg for errors
sudo dmesg | grep -iE "touchbar|ibridge|apple-ib" | tail -20
```

### 8.4 Expected dmesg Output (Good Boot)

```
[    1.5xx] apple-ibridge-hid 0003:05AC:8600.0001: input,hidraw1: USB HID v1.01 Keyboard [Apple Inc. iBridge]
[    1.6xx] apple-ibridge-hid 0003:05AC:8600.0002: hiddev96,hidraw0: USB HID v1.01 Device [Apple Inc. iBridge]
[    7.8xx] uvcvideo 1-3:1.0: Found UVC 1.50 device iBridge (05ac:8600)
```

**NO `Touchbar deactivated` message should appear.** If it does, the udev rebind rule is still active.

---

## 9. Troubleshooting

### 9.1 Display Lights Up During Boot But Turns Off

**Cause:** Udev rebind rule or bind service is still active.

**Fix:**
```bash
sudo rm -f /etc/udev/rules.d/99-mbp-t1-touchbar.rules
sudo systemctl disable mbp-t1-touchbar-bind.service
sudo udevadm control --reload-rules
sudo reboot
```

### 9.2 Display Never Lights Up

**Cause 1:** Wrong driver fork installed.

**Fix:** Use Heratiki's fork, not vfontanela's.

**Cause 2:** Module parameters not applied.

**Fix:**
```bash
cat /etc/modprobe.d/apple-touchbar.conf
# Should show: options apple_ib_tb idle_timeout=-1 dim_timeout=-1 fnmode=1

# If missing, recreate it and rebuild initramfs
echo 'options apple_ib_tb idle_timeout=-1 dim_timeout=-1 fnmode=1' | sudo tee /etc/modprobe.d/apple-touchbar.conf
sudo mkinitcpio -P
sudo reboot
```

**Cause 3:** Kernel too new.

**Fix:** Boot into `linux-lts`:
```bash
sudo pacman -S linux-lts linux-lts-headers
sudo mkinitcpio -P
# Reboot and select linux-lts from bootloader
```

### 9.3 Touch Bar Works But Keyboard Backlight Doesn't

**Fix:**
```bash
# Check if applespi is loaded
lsmod | grep applespi

# If not loaded
sudo modprobe applespi

# Check backlight control
ls -la /sys/class/leds/
```

### 9.4 DKMS Build Fails

**Fix:**
```bash
# Remove broken DKMS entry
sudo dkms remove applespi/0.1 --all

# Re-clone and reinstall
sudo rm -rf /usr/src/applespi-0.1
sudo git clone https://github.com/Heratiki/macbook12-spi-driver.git /usr/src/applespi-0.1
sudo dkms add applespi/0.1
sudo dkms install applespi/0.1
```

### 9.5 Touch Bar Display Is On But No Input

**Fix:** Check if `hid-sensor-hub` is interfering:
```bash
lsmod | grep hid_sensor_hub

# If loaded, it might be claiming the iBridge HID interface
# This is usually harmless with Heratiki's fork
```

---

## 10. What NOT to Do

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Use `vfontanela/macbookpro14-linux-support` | Use `Heratiki/macbook12-spi-driver` |
| Keep `/etc/udev/rules.d/99-mbp-t1-touchbar.rules` | Remove it — it causes the rebind bug |
| Enable `mbp-t1-touchbar-bind.service` | Disable it — not needed with Heratiki's fork |
| Install source in `/tmp/` | Install in `/usr/src/applespi-0.1` |
| Use `tiny-dfr` | It's for T2/Apple Silicon only |
| Set `idle_timeout=0` | Use `idle_timeout=-1` to keep display on |

---

## Architecture Notes (For Understanding)

### T1 vs T2 Touch Bar

| Feature | T1 (2016-2017) | T2 (2018+) / Apple Silicon |
|---------|----------------|---------------------------|
| Chip | Apple T1 | Apple T2 / M1/M2/M3 |
| Display Interface | Proprietary via T1 | DRM framebuffer (`appletbdrm`) |
| Driver | `apple_ib_tb` + `apple-ibridge-hid` | `tiny-dfr` + `appletbdrm` |
| Userspace Tool | None needed (T1 renders keys) | `tiny-dfr` (OS renders pixels) |

### How It Works on T1

1. **T1 chip boots** → initializes Touch Bar OLED via MIPI-DSI
2. **`apple_ibridge` loads** → establishes USB communication with T1
3. **`apple_ib_tb` loads** → sends "display layout" commands to T1 via USB HID
4. **T1 translates** layout commands into MIPI-DSI commands for the OLED
5. **Display shows** function keys, media keys, etc.
6. **Touch input** comes back via HID to `apple-ibridge-hid`

The display is **command-mode only** (not video mode). The T1 chip handles all rendering internally. You cannot draw arbitrary pixels — only send key layout commands.

---

## Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `/etc/modprobe.d/apple-touchbar.conf` | Module parameters | ✅ Required |
| `/etc/udev/rules.d/99-mbp-t1-touchbar.rules` | Udev rebind trigger | ❌ Must be REMOVED |
| `/etc/udev/rules.d/99-apple-touchbar.rules` | Input permissions | ✅ Keep |
| `/etc/udev/rules.d/50-apple-ibridge-power.rules` | Prevent USB autosuspend | ✅ Recommended |
| `/usr/src/applespi-0.1/` | DKMS source | ✅ Required |
| `/etc/mkinitcpio.conf` | Initramfs modules | ✅ Add apple modules |

---

*Guide version: 2026-07-21*
*Tested on: MacBook Pro 14,2 (2017) + CachyOS 7.1.3*
