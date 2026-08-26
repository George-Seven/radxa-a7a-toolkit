#!/bin/bash
# Radxa Cubie A7A: enable Bluetooth.
#
# The AIC8800D80 is a combo WiFi/BT chip on USB. Its Bluetooth driver ships with
# the BSP but is never loaded, so there is no adapter at all -- while WiFi works
# fine, which makes it look like a service or pairing problem.
set -e

[ "$(id -u)" = "0" ] || { echo "run with sudo"; exit 1; }

echo "=== chip present? ==="
lsusb | grep -i "AIC 8800" || echo "  WARNING: no AIC8800 found on USB"

echo "=== loading aic_btusb ==="
modprobe aic_btusb 2>/dev/null || insmod "/lib/modules/$(uname -r)/updates/aic_btusb.ko"
sleep 2
lsmod | grep -q aic_btusb && echo "  loaded" || { echo "  FAILED to load"; exit 1; }

echo "=== load at every boot ==="
echo aic_btusb > /etc/modules-load.d/aic_btusb.conf
echo "  wrote /etc/modules-load.d/aic_btusb.conf"

echo "=== PipeWire bluetooth audio support ==="
# Without this, speakers pair and connect but produce NO sound.
if ls /usr/lib/*/spa-0.2/bluez5/libspa-bluez5.so >/dev/null 2>&1; then
  echo "  already installed"
else
  apt-get install -y libspa-0.2-bluetooth
fi

echo "=== bring the adapter up ==="
hciconfig hci0 up 2>/dev/null || true
systemctl restart bluetooth
sleep 2
hciconfig 2>/dev/null | head -3
bluetoothctl list 2>/dev/null

# restart the user audio stack so it picks up the new plugin
for u in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
  runuser -u "$(id -nu "$u")" -- env XDG_RUNTIME_DIR="/run/user/$u" \
    systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true
done

cat <<'EOF'

Done. Pair a device with:
    bluetoothctl
    > power on
    > agent on
    > scan on
    > pair <MAC>
    > trust <MAC>
    > connect <MAC>

If a device connects but audio does not work, check for 2.4 GHz interference
before blaming Bluetooth -- see ../usb3-interference/. A USB 3.0 stick can jam
the whole band while leaving 5 GHz WiFi perfectly healthy.
EOF
