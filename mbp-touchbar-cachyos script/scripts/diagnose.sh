#!/usr/bin/env bash

echo "========================================"
echo "  MacBook Pro Touch Bar Diagnostic"
echo "========================================"
echo ""

echo "=== Kernel ==="
uname -a
echo ""

echo "=== Loaded Modules ==="
lsmod | grep -E "apple|ibridge|hid" || echo "No apple/ibridge modules loaded"
echo ""

echo "=== Module Parameters ==="
for param in idle_timeout dim_timeout fnmode; do
    val=$(cat /sys/module/apple_ib_tb/parameters/$param 2>/dev/null || echo "N/A")
    echo "apple_ib_tb.$param = $val"
done
echo ""

echo "=== USB Devices ==="
lsusb | grep -iE "apple|ibridge|8600" || echo "No iBridge found"
echo ""

echo "=== USB Power Management ==="
cat /sys/bus/usb/devices/1-3/power/control 2>/dev/null || echo "N/A"
echo ""

echo "=== Input Devices ==="
grep -H "" /sys/class/input/event*/device/name 2>/dev/null | grep -i "ibridge" || echo "No iBridge input devices"
echo ""

echo "=== Udev Rules ==="
ls -la /etc/udev/rules.d/ | grep -iE "apple|touchbar|ibridge" || echo "No matching udev rules"
echo ""

echo "=== Modprobe Config ==="
cat /etc/modprobe.d/apple-touchbar.conf 2>/dev/null || echo "No config found"
echo ""

echo "=== DKMS Status ==="
dkms status | grep -i apple || echo "No DKMS modules"
echo ""

echo "=== dmesg (last 15 lines) ==="
dmesg | grep -iE "touchbar|ibridge|apple-ib" | tail -15 || echo "No relevant dmesg entries"
echo ""

echo "========================================"
echo "  Diagnostic Complete"
echo "========================================"
