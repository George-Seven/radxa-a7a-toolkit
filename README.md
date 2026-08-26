# Radxa Cubie A7A Toolkit

Fixes, tools and game launchers for the **Radxa Cubie A7A** (Allwinner A733 / sun60iw2,
PowerVR B-Series BXM-4-64) running Debian 13.

Everything here came out of debugging a real board. Each fix documents *why* it works,
not just what to run. Several are bugs in the stock board support that affect every A7A.

## What's here

| Area | Fix | Impact |
|---|---|---|
| [Analog audio](board-fixes/analog-audio/) | Codec declared at the wrong I2C address in the device tree | **3.5 mm jack dead** on stock images |
| [Bluetooth](board-fixes/bluetooth/) | `aic_btusb` ships but never loads | No Bluetooth adapter at all |
| [USB 3.0 interference](board-fixes/usb3-interference/) | USB 3.0 jams 2.4 GHz | Wireless keyboards/mice die, BT unusable |
| [Display colour](board-fixes/display-color/) | PowerVR red/blue channel swap | Red and blue inverted in GL apps |
| [Tools](tools/) | GPU clock control, PowerVR Xorg, gl4es | 400-1400 MHz |
| [Games](games/) | Launchers with big.LITTLE pinning | 28 to 50 fps in one case |

## Hardware notes

The A733 has 8 cores, but **not** 8 equal cores:

```
cpu0-5   Cortex-A55  @ 2.8 GHz   (little)
cpu6-7   Cortex-A76  @ 3.0 GHz   (big)
```

Single-threaded games should own the two A76s while everything else is pushed to the
A55s. The launchers here do that automatically.

**Always leave one A55 free.** This board wedges hard under memory or I/O pressure --
it keeps answering pings while SSH stops accepting connections entirely, and only a
power cycle recovers it. Reserving a core for `sshd` is what stops a heavy workload
from locking you out of your own machine.

## A word on measurement

Where this repo quotes numbers, they were measured on hardware, not estimated. If you
change something, measure it the same way rather than trusting the change to help --
several "obvious" optimisations here turned out to do nothing, and one made things
worse. The GPU overclock is the clearest example: it is real, it works, and on a
CPU-bound workload it buys you nothing but heat.
