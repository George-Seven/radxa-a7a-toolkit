# Tools

## a7a-clock / a7a-clock-gui

GPU clock control for the A733. Writes boot entries for each frequency/voltage pair, so
GPU changes need a reboot; DRAM frequency can be changed at runtime via devfreq.

    a7a-clock gpu 1008        # 400 600 800 1008 1200 1300 1400
    a7a-clock ram 2040        # runtime, no reboot

Voltages are paired with frequencies by a built-in table. Overclocking is at your own
risk: more heat, more power draw, instability if cooling or supply cannot keep up.

**Measure before you overclock.** On a CPU-bound workload a GPU overclock buys nothing.
Test by running at half the pixel count (640x480 vs 1024x600): if peak framerate barely
moves, you are CPU-bound and more GPU clock will not help.

There is no runtime GPU clock knob on this SoC -- `/sys/class/devfreq` exposes only the
NPU and the DRAM controller, which is why GPU changes go through boot entries.

## Xorg-pvr

Starts Xorg on the PowerVR driver (GPU-accelerated glamor). The tradeoff on this board:
GPU mode is smooth but has the red/blue swap; software mode has correct colours but is
laggy. See ../board-fixes/display-color/.

## gl4es-run

Runs a legacy OpenGL application through gl4es (GL to GLES translation) for software that
predates GLES.
