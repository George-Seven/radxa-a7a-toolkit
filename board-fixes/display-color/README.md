# PowerVR red/blue channel swap

The PowerVR GLES stack on this board presents buffers with red and blue swapped, so GL
applications render with inverted colours -- a blue sky comes out yellow, skin tones go
blue-grey, red tail lights go blue.

## Two independent fixes -- pick one, never both

### 1. Kernel display-engine patch (board-wide)

Fixes the desktop and every GL app at once. See
[Rabs9/radxa-cubie-a7a-kernel](https://github.com/Rabs9/radxa-cubie-a7a-kernel),
`patches/0001-sunxi-drm-de-swap-rb-channels-for-pvr-glamor.patch`.

Requires a full kernel rebuild -- `CONFIG_AW_DRM=y` is built in, not a module.
Tradeoff: the boot logo colours invert (cosmetic).

Note this fixes the **desktop compositor path**. It does not necessarily fix a
fullscreen GL application that presents its own buffers.

### 2. Application-side swizzle

For anything built on librw (see [../../games/not-vice-city/](../../games/not-vice-city/)),
swap the channels in the fragment output:

```c
#define FRAGCOLOR(c) (fragColor = (c).bgra)
```

## The trap that cost hours

**Applying the swizzle in more than one render pass cancels it out.**

If the application renders its 3D scene into an offscreen buffer and then blits that
through a post-processing pass, and *both* shaders use the swizzled macro, the scene
gets swapped **twice** and comes out inverted again -- while the HUD, drawn in a single
pass, looks perfectly correct.

The result is one frame containing correct 2D and inverted 3D, which is baffling until
you count the passes. In our case the culprit was a colour-filter post-processing pass;
disabling it fixed the 3D world instantly and removed a full-screen copy per frame as a
bonus.

If you hit this: either disable the extra pass, or apply the swizzle only at final
present.

## Verify objectively, not by eye

Colour judgements by eye are unreliable, especially at night or under a colour filter.
Compare rendered pixels against known constants in the source -- hardcoded HUD colours
are ideal. With red and blue swapped they come back **exactly byte-reversed**:

```
expected (0,207,133)    measured (133,207,0)
expected (255,150,225)  measured (225,150,255)
expected (27,89,130)    measured (130,89,27)
```

Three independent constants reversing exactly is proof, not an impression. Game data
files are also worth checking directly -- decode a texture you know the colour of (an
ivy texture should be green-dominant) to rule out the assets before blaming the renderer.
