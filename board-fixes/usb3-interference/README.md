# USB 3.0 jams 2.4 GHz (keyboards, mice, Bluetooth)

Not an A7A bug -- a physics problem that bites hard on small boards where the USB ports,
the wireless dongle and the WiFi/BT chip all sit within a few centimetres of each other.

Worth reading **before** you debug drivers, because every symptom points the wrong way.

## Symptoms

- 2.4 GHz wireless keyboard or mouse works only within a few **inches** of its dongle
- Bluetooth devices connect, report "connected", and then do not work
- Swapping keyboards or mice changes nothing
- **WiFi is completely fine** -- because it is on 5 GHz
- A keyboard plugged in by cable may also misbehave

## Cause

USB 3.0 SuperSpeed signalling (5 Gbps) radiates broadband noise whose harmonics land
squarely in the 2.4-2.5 GHz band. Intel documented this publicly in whitepaper 327216.
Poorly shielded drives and cables are the worst offenders, and it is emitted mainly
during active transfers.

The giveaway is the **band split**: 5 GHz WiFi keeps working perfectly on the *same
chip* whose 2.4 GHz Bluetooth is dead. A driver or configuration fault would break both
halves. Only interference is that selective.

## Diagnose

```
lsusb -t
```

Anything at `5000M` or `10000M` is running SuperSpeed and is a suspect:

```
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=xhci-hcd/1p, 10000M
    |__ Port 001: Dev 002, ... Driver=usb-storage, 5000M     <- the culprit
```

Unplug it and retest the keyboard from across the room. That single step is definitive.

## Fixes, cheapest first

1. **Run the device at USB 2.0 speed** -- via a USB 2.0 port, hub, or extension cable.
   The SuperSpeed lanes never activate so nothing is radiated. Costs throughput
   (about 40 MB/s), nothing else.
2. **Move the wireless dongle away** on an extension cable. Distance helps a lot.
3. **Put WiFi on 5 GHz** -- unaffected by this entirely.
4. Better shielded drive or cable, or ferrite cores.

## One thing that confuses people

A USB 2.0 device plugged into a USB 3.0 *socket* is harmless. It only uses the old USB
2.0 wire pair, the SuperSpeed lanes stay idle, and nothing is transmitted. It is the
negotiated signalling speed that matters, not the colour of the port.

Check with `lsusb -t`: if it says `480M`, it is not your problem.
