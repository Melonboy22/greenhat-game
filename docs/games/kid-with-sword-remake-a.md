# kid with sword remake, A builds: Ocarina of Time on the Mighty Green Kokiri Kid base

The A builds run The Legend of Zelda: Ocarina of Time (Switch 2, title ID `0400486024DEC000`, update v131072) on the iPhone from Aznracer's [Mighty Green Kokiri Kid](https://github.com/Aznracer/Mighty-Green-Kokiri-Kid) v3 (60 fps on an iPhone at render scale 0.75, see [its note](mighty-green-kokiri-kid.md)) with this fork's touch controls and launcher options on top. The V builds (V1 to V16) are on the `kid-with-sword-remake` branch, on another base.

**Nothing from the game is in this repository.** You need your own dump of the game.

## Builds

| Build | IPA | What changed | Tested |
|---|---|---|---|
| A1 | `OcarinaOfTime-A1.ipa`, 3.3 GB, split | Mighty Green Kokiri Kid v3 (`a044609c`) plus this fork's Forest touch theme, Native layout and X jump icon; Peak8D's movie fix (`99b1b8d0`, below) | Mac, 720p handheld settings of the v3 note: 60 fps in Kokiri Forest after loading (0 dropped frames, p99 16.7 ms), the 3D scene 960x540 scaled to 1280x720 by MetalFX; the title movie at 60 fps. Not yet on the iPhone |
| A2 | `OcarinaOfTime-A2.ipa`, 3.3 GB, split, with an app icon | A1 plus: the Native layout drawn as flat translucent keys instead of glass; the launcher's **Frame rate** (30 / 60, this fork's V4 frame step); the launcher's **Render scale** slider (0.5 to 1.0) starting at 0.75 | iPhone: ran much worse than A1, with the env.txt below as it was then (it had `DM_NVN_GMEM_SKIP=1`) and the host's frame step at 60 |
| A3 | `OcarinaOfTime-A3.ipa`, split, with the app icon | A2 with: **Frame rate** back to the game's own step (60 fps, as A1 and v3 ran), 30 still offered; launcher rows an `env.txt` sets start at its value and can still be changed, so the **Render scale** slider moves with `DM_RENDER_SCALE=0.75` in the file; the env.txt is v3's, unchanged | Not yet on the iPhone |
| A4 | `OcarinaOfTime-A4.ipa`, split, with the app icon | A3 plus: shader-code pools no longer made resident (upstream #1484, 334 MB; via this fork's `2191f7ac`); the launcher's **Preset** (Standard / **Potato**): Potato sets the profile's `potato` list for phones with less memory and locks the Render scale slider at 0.6; the memory readout logs the GPU memory and its peak (`residency set N MB (peak N MB)`) | Not yet on the iPhone. Potato is not measured as a whole (see Potato below) |

Both IPAs carry no settings file: the settings go in the app's `Documents/env.txt` (below). They take the same game image (`romfs.img`, size 26,247,607,298 bytes, index `79d6727a8276e44a`), so a phone that has one for A1 keeps it for A2.

## What the A builds add to v3

| Change | Files | Why |
|---|---|---|
| The touch controls from `kid-with-sword-remake` (the Native layout, the Forest theme, X as a jump) | `dm/ios/Sources/DmGamepad.m`, `GameMenu.swift`, `dm/games/game.py`, `game.tsv` (`pad_layout native`, `pad_theme forest`) | The Native layout: a floating left stick, the camera on the right half, icon keys with the button's letter in a chip |
| The movie network drawn by MetalFX (Peak8D `99b1b8d0`, `DM_NDVE`, default `metalfx`) | `dm/gfx/nvn/nvn_mtl.m` | The movie player's RLA1 network took about 37 ms of GPU a movie frame: the title and intro movies ran at about 26 fps. On the Mac, 2 dropped frames in the movie's first 600 against 100 to 223 before |
| Translucent Native keys (A2) | `dm/ios/Sources/DmGamepad.m` (`glassDiscFill`) | The glass style (gradient sheen, specular rim, highlight) replaced by the 2D and 3D layouts' translucent white: fill white 0.14, outline white 0.38, pressed 0.45; the stick's ring white 0.06 |
| Frame rate limiter (A2; default changed in A3) | `dm/games/0400486024DEC000/patches.py` (`fps_limit`, `ctx.fps_limit`), `game.tsv` (`fps_target 0`), `dm/tools/patch_nso.py` (fixups key `FPS_LIMIT`), `dm/games/settings.tsv` / `settings.py` (Frame rate row: `60 fps (game's own)` and `30 fps`) | This fork's V4 stub at main+0x3b4f074: the game's frame-rate controller takes the host's step, so 30 fps is the game's own 30 fps mode at full speed. It sits beside v3's `real_speed` (state +0x38) and `render_scale` (state +0x10) stubs. A2 defaulted to 60, which hands every frame to the host's frame step (`hle_nvn.c` `fstep_tick`, its holds and probes) instead of the game's own interval; A3 defaults to 0, A1's behaviour, and the stub then runs the original code |
| env.txt rows stay changeable (A3) | `dm/ios/Sources/LauncherSettings.swift` (`fromFile`, `base`) | A row an env file set was greyed out: with v3's env.txt (`DM_RENDER_SCALE=0.75`) the Render scale slider could not move. The row now starts at the file's value; a choice saved in the launcher wins over the file, Reset goes back to it. Values set at launch (Xcode) stay fixed |
| Render scale default (A2) | `dm/games/game.py` (profile key `render_scale`, `DM_GAME_RENDER_SCALE`), `dm/host/loader.c`, `dm/games/settings.tsv`, `game.tsv` (`render_scale 0.75`) | The launcher already had a Render scale slider for this build (the rewriter marks `RENDER_SCALE`), starting at 1.0, the game's dynamic resolution. The profile now gives its default |

| Build | What changed | Tested |
|---|---|---|
| A5 | The CPU upload gate (MenAtCafe's mkw-neo): with the guest memory in files, a texture whose storage no zero-copy buffer covers is uploaded on the CPU. Potato skips the pipeline prewarm (`DM_PSO_MANIFEST=off`). The iPhone counts purgeable space as free and stops the game at 2.5 GB free | iPhone, Potato (log 44): footprint 6.0 GB, 2.4 GB of it compressed |
| A6 | Potato keeps memory pools over 512 MB in the guest files (`DM_POOL_ANON_MAX_MB=512`): only the chunks the GPU reaches are wired | Mac, Potato, played by hand into Kokiri Forest: footprint 4.78 GB (peak 4.83) against 6.31 (peak 6.53), the anonymous pools 2,505 → 746 MB (vmmap). Not yet on the iPhone |

## Potato (A4 to A6)

Aimed at a GPU memory peak under 5 GB, for phones with less memory. Standard peaks at 5.6 GB in Kokiri Forest, on the Mac (with the guest memory in files, as on the iPhone) as on the v3 author's iPhone (5,728 MB). There it holds about 2.1 GB of the game's memory pools the GPU reads, 2.2 GB of textures, 0.5 GB of render-target heaps and 0.2 GB of other buffers.

| Setting | On the Mac (2-minute runs to Kokiri Forest) |
|---|---|
| `DM_RENDER_SCALE=0.6` | 0.65 alone: no memory saved (peak 5,786 MB); it is in Potato for the GPU time |
| `DM_NVN_TEX_SOFT=1` | this fork's V15 ran with it on the iPhone; not measured here |
| `DM_NVN_RT_LOSSY=1` | this fork's V15 ran with it on the iPhone; not measured here |
| `DM_NVN_GMEM_NOBIG=1` | pools 2,138 → 1,407 MB, in a run that froze for another setting |
| `DM_NVN_RES_EVICT_MB=4400` | new: the guard lets go of idle textures from 4,400 MB, without ever stopping the game |
| `DM_NVN_TEX_RECYCLE_MB=64`, `DM_NVN_ALIAS_SWEEP=600` | a smaller bin of recycled textures, unused shared textures swept sooner |
| ~~`DM_NVN_TEX_MIP_SKIP=512`~~ | **froze the game** right after the save loaded (the main thread spinning); not in Potato |

`DM_NVN_TEX_MIP_LEVELS`, in the v3 env.txt, is read nowhere: it does nothing.

## Building

As in the [v3 note](mighty-green-kokiri-kid.md#build), from a dump folder (`base/`, `updates/131072/`), with `G` the dump folder and `B` the build folder:

```sh
DM_DYNAMIC_FPS=1 python3 scripts/build_ipa_from_nsp.py "$G" --work-dir "$B" --keep-extracted --romfs separate \
  --allow-shader-regressions -o "$G/OcarinaOfTime-A3.ipa"
```

The script needs Python 3.12 or newer (the RomFS image). No `--env-file`: the settings go on the phone. An `icon.jpg` beside the extracted game (`$B/extract/v131072/icon.jpg`) becomes the app icon. A change to `game.tsv` re-runs the shader split and the shader translation (about 25 minutes on a MacBook Air M5 for the Mac and as much for the iPhone; the Metal libraries themselves are reused).

## env.txt

Put this in the app's `Documents/env.txt` (one setting per line): the [v3 note](mighty-green-kokiri-kid.md#envtxt)'s settings, unchanged. From A3 the launcher starts each row the file sets at its value and you can still change it there (A1 and A2 greyed those rows out):

```
DM_PRESENT_SNAP=1
DM_PRESENT_UPSCALE=off
DM_RENDER_SCALE=0.75
DM_NDSR=metalfx
DM_NVN_RES_LIMIT_MB=6900
DM_NVN_TEX_MIP_SKIP=1024
DM_NVN_TEX_MIP_LEVELS=1
DM_TEX_LAZY=2
DM_TEX_LAZY_MIN_KB=1024
DM_TEX_RELEASE=1
DM_OPMODE=0
DM_GFX_SCALE=2
DM_NVN_DISPATCH_OVERLAP=0
```

The env.txt first given with A2 had `DM_NVN_GMEM_SKIP=1` added and no `DM_RENDER_SCALE`: on the v3 author's iPhone `DM_NVN_GMEM_SKIP=1` raised the title screen's GPU time from 24 to 35 ms (20 to 30 fps), so it is out.

## Open

- A3 is not yet tested on the iPhone: the frame rate at the game's own step and at 30, the slider and the translucent keys need a phone run (Documents/log.txt shows `launcher: DM_RENDER_SCALE=...` and `3D views rendered at ...`).
- `test_env_switches` and `test_launcher_settings` fail on v3 with these commits as without them: switches from the v3 base have no rows in `docs/env_switches.tsv` (`DM_TEX_LAZY`, `DM_TEX_LAZY_MIN_KB`, `DM_WAKE_UNLOCKED`, `DM_FRAME_WG`), and `DM_PAD_THEME` is an iPhone-only setting the test does not list.
- Next (A4): fixes that need no shader rebuild, from Peak8D's oot2 branches (`6ab66b72` pool heap textures without GPU-optimized contents, `f9eb7d34` and `e13a1eb1` render targets in the pools' heaps) and upstream (`fa9cfb84`, PR #1644; PRs #1491 and #1492). After that (A5), one shader rebuild with upstream's mesh and depth fixes (`d777f0a3`, `d365496d`, `473c9026`, `ffebfd59`).
