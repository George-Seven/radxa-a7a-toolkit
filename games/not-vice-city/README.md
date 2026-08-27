# Not Vice City on the Radxa A7A

A port of the [reVC](https://github.com/mrxenginner/reVC) engine to the Radxa Cubie A7A,
with hardware-accelerated rendering on the PowerVR BXM-4-64 via OpenGL ES.

**You must supply your own game data.** No game assets are included in this repository
and none will be. You need a legally owned copy of the original PC release.

Measured on the board: **50 fps** at 1024x600, up from 28.

## What had to be fixed

Every one of these was a real crash or visual bug, with the evidence in the patch series:

| Fix | Problem |
|---|---|
| Bounded particle parse | Config with more particle types than the fixed array wrote **past the end of it**, corrupting the player model pointer -- crash on spawn |
| Texture cache bypass | The conversion cache uses a 32-bit file offset; a cache over 2 GB wraps and produces garbage entries |
| Capacity raises | Extra model IDs indexed past a fixed table with no bounds check |
| Radar bounds guard | Blip icon IDs beyond the sprite table -> unchecked index -> crash |
| Mipmap handling | GLES samples a mipmap-incomplete texture as **solid black** |
| GLES + EGL forcing | GLFW picked GLX and silently fell back to software rendering |
| Colour swizzle | PowerVR red/blue swap |

Full detail in [patches/](patches/). Each patch is small and commented.

## The two most interesting bugs

**Particle overflow.** The engine reads particle definitions into a fixed array guarded
only by a non-fatal assert. A config file with more entries than capacity writes past
the array -- and the next things in memory are the player model pointer and a texture
slot. The crash surfaced much later, during player spawn, with a garbage pointer whose
bytes turned out to be **ASCII text from a particle name**. That text is what identified
the real cause.

**Black world.** After bypassing the texture cache, distant surfaces rendered pure black
while near ones were fine -- it looked like a spotlight following the player. Cause: the
renderer claims a full mipmap chain but only ever uploads level 0, and per the GLES spec
a mipmap-incomplete texture samples as opaque black. The cache had been masking it by
writing complete chains. Roads recede steeply so they hit high mip levels; buildings face
you and stayed lit, which made it look like a lighting bug.

Measured, same scene, near to far:

```
mips on:   123 -> 99 -> 80 -> 53 -> 13 -> 1.9 -> 1.6   (collapses to black)
mips off:   72 -> 56 -> 54 -> 49 -> 52 -> 46           (holds)
```

Fog fades toward a fog colour; only a black texture crashes to 1.6/255. The shipped fix
disables mipmaps under GLES -- correct output, at the cost of some shimmer on distant
textures. Filling the chain properly would be the better fix and is an open task.

## Build

```
git clone <this repo>
cd radxa-a7a-toolkit/games/not-vice-city/engine
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DLIBRW_PLATFORM=GL3 -DLIBRW_GL3_GFXLIB=GLFW
cmake --build build -j8
```

Dependencies:

```
sudo apt install p7zip-full libglfw3-dev libopenal-dev libglew-dev \
                 libsdl2-dev libmpg123-dev libsndfile1-dev libvorbis-dev
```

Then copy your game data next to the binary and use the `vicecity-gpu` launcher.

## Launcher

`vicecity-gpu` handles the board-specific parts:

- Pins the main thread to the two A76 cores, helper threads to the A55s
- Keeps GPU driver threads on the big cores (moving them **hurts** -- they sit on the
  present path)
- Pushes the desktop to the little cores while playing, restores on exit
- Reserves one A55 so `sshd` can never be starved
- Stages read-hot data into a RAM disk, with a free-memory check and SD fallback
- **Memory guard**: stops the game if free RAM drops below 700 MB

That last one matters. The engine never releases streamed textures (it accounts
bytes-on-disk, not RAM), so memory grows the whole session. Without the guard, a long
session exhausts RAM and wedges the entire board -- pings fine, SSH dead, power cycle
only. Losing the game is the better outcome.

## Performance notes

Tuning that actually moved the needle, measured:

| Change | Effect |
|---|---|
| Frame cap 30 -> 60 | 28 -> 50 fps (it was pinned at the cap) |
| Read-hot data in RAM | Removed the streaming stalls (worst 10%: 15-22 -> 46 fps) |
| Density 2.5 -> 1.0 | Mod default was 4x the engine default |
| MultiSampling 3 -> 0 | That value means **8x MSAA**, not "level 3" |
| Colour filter off | Removes a full-screen copy per frame |

Tuning that did **nothing**: GPU overclock. Halving the pixel count left the peak
framerate unchanged (53.5 vs 54.1), which proves the workload is CPU-bound. Texture
decompression runs on the main thread, inside the frame, alongside all the AI and
physics. Test before you overclock.
