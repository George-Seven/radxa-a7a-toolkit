# Fix: Bluetooth (adapter missing entirely)

**Symptom:** no Bluetooth adapter at all. `bluetoothctl list` is empty, `rfkill list`
shows only Wireless LAN, `hciconfig` prints nothing -- yet `bluetooth.service` is
enabled and active, which makes it look like a service problem.

## Root cause

Nothing is broken. The AIC8800D80 is a combo WiFi/Bluetooth chip on USB, and its
Bluetooth driver (`aic_btusb`) ships with the BSP but is **never loaded**. Only the
WiFi half comes up automatically.

```
$ lsusb
Bus 001 Device 005: ID a69c:8d81 AICSemi AIC 8800D80    <- chip is present

$ lsmod | grep aic
aic8800_fdrv   475136  0                                 <- WiFi only, no BT
```

## Apply

```
sudo ./enable-bluetooth.sh
```

No reboot needed. You should immediately get:

```
hci0:  Type: Primary  Bus: USB
       BD Address: xx:xx:xx:xx:xx:xx
```

The script does three things:

1. Loads `aic_btusb`
2. Writes `/etc/modules-load.d/aic_btusb.conf` so it loads at every boot
3. Installs `libspa-0.2-bluetooth`

That third step matters more than it looks. **Without it PipeWire has no Bluetooth audio
support**, so speakers pair and connect successfully and then produce no sound -- a
confusing failure that looks like a pairing problem.

## If Bluetooth connects but does not work

Read [../usb3-interference/](../usb3-interference/) before blaming the driver.
Bluetooth shares 2.4 GHz with wireless keyboards and mice, and on this board a USB 3.0
flash drive was jamming the entire band -- devices paired and connected fine, then no
data got through.

Quick check: if your 5 GHz WiFi works but Bluetooth does not, and both run on this same
chip, the driver is not your problem.
