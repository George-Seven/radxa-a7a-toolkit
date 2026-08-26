# Fix: 3.5 mm analog audio (dead on stock images)

**Symptom:** no sound from the headphone jack. `aplay -l` lists only HDMI. Volume and
mute look completely normal, which sends you chasing PipeWire and ALSA settings for
hours. The problem is a layer below all of that: the analog sound card does not exist.

## Root cause

The device tree declares the AC101B codec at I2C address **0x3e**. The chip on the board
actually answers at **0x1a**. The driver binds, talks to an address with nothing on it,
and the sound card is never created:

```
sunxi:sound-mach:[ERR]: simple_dai_link_of failed
No soundcards found.
```

The kernel is explicit about what went wrong:

```
twi_sunxi-7085000.twi:[ERR]: Address + Write bit transmitted, ACK not received
```

Confirm it on your own board by scanning the codec bus:

```
$ sudo i2cdetect -y -r 15
10: -- -- ... 1a --      <- the real chip, answering
30: -- -- ... UU --      <- 0x3e, claimed by the driver, nothing there
```

`UU` means a driver has claimed that address. It does **not** mean a device replied.
That distinction is the whole bug.

## Apply

```
sudo ./fix-analog-audio.sh
sudo reboot
```

The script patches a **copy** of the DTB and adds a separate boot entry, leaving your
working configuration untouched. If anything misbehaves, pick the original entry at the
U-Boot menu (30 second timeout).

## After reboot

A second card appears:

```
card 1: sunxiac101b [sunxi-ac101b]
```

The codec output pins come up **disabled**, so enable them and make it stick:

```
amixer -c 1 sset HPOUT on
amixer -c 1 sset LINEOUTL on
amixer -c 1 sset LINEOUTR on
sudo alsactl store
```

## Status and honest caveat

This creates the sound card and enables the outputs. On the board this was developed on,
audio still did not reach the jack, and the codec logs register errors during setup:

```
sunxi-ac101b 15-001a: ASoC: error at ... register: [0x0000001d] -22
sunxi-ac101b 15-001a: ASoC: error at ... register: [0x00000081] -22
```

`-22` is `EINVAL` -- the driver is writing registers the chip rejects, which suggests
the in-tree register map does not fully match this chip revision.

**The address fix is definitely correct and necessary.** It may not be sufficient on
every board. If you get working audio after this, please open an issue and say so. If
you do not, those register errors are the next thread to pull.

Upstream: this address should be corrected in Radxa's board DTS.
