# kid with sword remake, A builds: Ocarina of Time on the Mighty Green Kokiri Kid base

The A builds run The Legend of Zelda: Ocarina of Time (Switch 2, title ID `0400486024DEC000`, update v131072) on the iPhone from Aznracer's [Mighty Green Kokiri Kid](https://github.com/Aznracer/Mighty-Green-Kokiri-Kid) v3 (60 fps on an iPhone at render scale 0.75, see [its note](mighty-green-kokiri-kid.md)) with this fork's touch controls and launcher options on top. The V builds (V1 to V16) are on the `kid-with-sword-remake` branch, on another base.

**Nothing from the game is in this repository.** You need your own dump of the game.

**Current: A15.** Launcher settings for a steady 30 fps: Standard, Frame rate 30, Render scale 1.0 (the game's own dynamic resolution, which steps down before frames go late since A11), or Potato (render scale 0.5, locked). Both presets fill the system's shader cache in the background from a full list of the game's pipelines (A12), so areas build no pipeline once it has passed them. The touch controls follow the game's own Basic Controls ([Touch controls](#touch-controls)). A8 to A12 are not yet tested on the iPhone.

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
| A7 | Native touch layout built around Ocarina of Time (`DmGamepad.m`): B (sword) the large key under the thumb, an arc around it of A (roll, interact), R (shield), ZL (target) and X (jump), Y (items) apart at the top right (the key map was wrong: the game has no shield button and attacks with Y; corrected in A12); + and − larger, at the top right beside the menu, off the hearts. Icons drawn for the game (sword, roll arrow round an "!", shield, fairy, winged boot, ocarina, chest, map scroll) with the button's letter in a chip. A quick tap on ZL (under 0.3 s) locks the target on until the next tap (gold ring, padlock); a longer press is a plain hold; a pose change or the menu releases it. A D-pad above the stick at the left: it keeps the touches that land on it (a touch keeps what it took at touch-down, so the stick's thumb never presses it), a touch in the band just around it starts no stick, and a floating stick that lands near it is centred lower, so its ring stays 10 points clear | Built; not yet on the iPhone |
| A8 | A7 plus seedds/nxnative PR 1714 (`27764ec1`, `a650827a`, `4aeafc27`, open): profile key `gpu_ts_hz`, `31250000` for this game. It reads raw GPU counter reports at the Switch 2's 31.25 MHz system counter rate, and at NVN's 614.4 MHz its wind and particle step was 19.66 times too large, so grass, leaves and hanging plants shimmered as if in a gale. Host only (`nvn_timestamp.h`), no shader change; `DM_NVN_TS_HZ` overrides it. The foliage jitter fix (PR 1343, `6941aa84`) was already in the base. From upstream `6121fd75`, two host parts: a mid-submission cut commits only when the GPU has run out of work (`sub_cut`, `g_seg_inflight`; with one timestamp per submission, as this profile, since segment mode needs upstream's timestamp heap; `DM_NVN_CUT_BUSY=0` restores every commit), where queued command buffers had left the GPU waiting 5-40 ms (frames 13 / 52 ms in turn); and the readback buffer cache evicts its oldest instead of refusing every new size (600 buffers of 0.5 MB made and dropped per 300 frames) | `t_timestamp`: 25 checks, 0 failed; `nvn_mtl.m` compiles. Not yet on the iPhone |
| A9 | A8 with the baked env changed (`env-older-iphones.txt`, no code change): `DM_POOL_ANON_MAX_MB=512` and `DM_NVN_GMEM_NOBIG=1` for both presets (Standard reached 6.85 GB on an A20 Pro, log 46, 2.6 GB of it memory pools moved into anonymous memory; Potato already had both; without NOBIG a pool kept in the files is still mapped and wired whole); `DM_TEX_LAZY_MIN_KB` 1024 → 4096, so the foliage's mid-size textures read through the texture table are always made (they popped in and out; logs 41-45 had 65,536+ table entries left empty); `DM_NDSR=metalfx` removed, so agl's four-dispatch upscaler runs the game's own network (MetalFX's spatial scaler left the grass shimmering; about 1 ms more GPU) | Not yet on the iPhone. Log 45 (A8, Potato, 10.6 min): footprint 4.1-4.4 GB, peak 4.87 GB; 85 s of long frames compiling pipelines for areas not seen before. Log 46 (A8, Standard, 60 fps): 57 fps average, 55-70 % of frames over 16.7 ms, CPU-side frame work 8-17 ms with 1-3 % of it on performance cores at thermal state 2 |
| A10 | A9 plus: Standard takes Potato's memory housekeeping (baked `DM_PSO_MANIFEST=off`, `DM_NVN_RES_EVICT_MB=4400`, `DM_NVN_TEX_RECYCLE_MB=64`, `DM_NVN_ALIAS_SWEEP=600`; Mac, Standard at 0.75 and 30 fps: peak 4.37 → 4.33 GB, long frames 57 → 45), none of its quality cuts; Potato's render scale 0.6 → 0.5 (`game.tsv` `potato`); the dynamic resolution's GPU meter budgets the target's frame time (`patches.py` `gpu_meter_budget`, stan69b/nxnative oot-main `f4b3abd6`: at a 30 cap a 25 ms frame read 150 % of 1/60 s and the scene stayed at its floor); counter reports per segment while the dynamic resolution runs (render scale 1.0; `nvn_mtl.m` `seg_drs`), so the meter reads GPU time, and one time per submission with A8's commit pacing at a fixed scale. Ported but inert: seedds/nxnative PR 1572 (`bar_frag_only`): `DM_NVN_BARRIER=game` skipped no pass barrier on the Mac (26,400 full / 0 saved), with and without `DM_NVN_POOL_HEAP=0`, so it is not baked | Mac checks only. Log 47 (A9, Standard 30 fps, A20 Pro): 5.43 GB peak; the game switched its present interval between 2 and 3 (256 times each) where the GPU took 28-34 ms a frame |
| A11 | A10 plus: the GPU meter's budget is a share of the target's frame time (`patches.py` `gpu_meter_budget`, state +0x18, `DM_DRS_BUDGET`, default 0.85: 28.3 ms at 30 fps), so the dynamic resolution steps down before frames go late; the scale the game stores is reported (`render_scale` store stub → state +0x14; the log's `3D scale up to frame` line beside each timing line) | Log 48 (A10, Standard 30 fps, render scale 1.0, A20 Pro, thermal 0): the scene stayed at 1920x1080, GPU p50 29-30 ms / p95 35-37 ms in Kokiri Forest, under the controller's 98 % of 33.3 ms, so it never stepped down; 177 interval switches between 2 and 3 |
| A12 | A11 plus: the warm-only prewarm (`DM_PSO_WARM_ONLY=1` baked for both presets, replacing `DM_PSO_MANIFEST=off`; `nvn_mtl.m` `warm_only`): the profile's prewarm list, now Aznracer's v3 list of 40,156 lines (13,205 render and 2,144 compute pipelines), is built on one utility-QoS thread in the background, never before the first frame, and each pipeline is let go once built, so what stays is the system's Metal shader cache (shader-only lines skipped; shaders held only by the tasks using them). Log 45: pipelines never built on the device cost about 300 ms each on the submit thread (compute 0.5-1.8 s), cached ones about 0.4 ms. Touch layout corrected to the game's own Basic Controls (pause menu): Y attack (the large key), A actions, B put away (small, bottom right), X jump, ZL target (holding it raises the shield: the tester's R did nothing, R is quick select), ZR use item (new), R quick select; icons bow, item ring and back arrow added | Not yet on the iPhone. Mac: A11's dynamic resolution stepped from 0.75 to 0.444 under a forced budget (`DM_DRS_BUDGET=0.15`) |
| A13 | A12 plus: under a frame rate target the game steps by the host's hold alone (`hle_nvn.c`: state +0x38 stays 0 while `fps_step_cap` decides the hold; `DM_FRAME_DELTA=1` restores the measured step). The game's own step already equals the hold the host hands its frame-rate controller (`fps_limit`), and the real-speed stub took the larger of it and the mean of the last 8 present intervals, so every change of hold lagged by up to 8 frames: after a 20 fps stretch the camera ran 1.5 times as fast for 8 frames at 30, after a late frame about 6 % fast (camera jitter whenever the frame rate was not steady). The GPU meter stub also stores the GPU time the game's meter measured (state +0x1c, `s0` at main+0x5aa54), logged on the `3D scale` line | Log 52 (A12, Standard 30 fps, render scale 1.0, A20 Pro): the hold changed 116 times in 89 s; the scene stayed at 0.750 with the GPU at 29-30 ms (p95 33-38 ms), so the game's meter reads less than the frame's GPU time; 10-26 dropped frames per 300 in Kokiri Forest |
| A14 | A13 plus seedds/nxnative PR 1752 (`f5c4612a`, open; shader chain `08ca2ce4be8d`), rewritten for this tree's pool table: raw loads through one pointer at constant offsets resolve their pool once per run (`GlobalToStorage.ResolveRawRuns`, `RawResolveRange`) instead of a lookup per word. The range helper uses this tree's growing table (the count in entry 0), its hint (slot words 6 and 7) and its count-based search; the resolved load takes the bind-time pointer site too (6 arguments) and falls back to the full lookup (private words, site, hint, search) for entry 0. It replaces `dmsh_wide.raw_fours` wherever a run is found (`DMSH_NO_RAW_RUNS=1`, tests only, turns runs off). The PR's second commit (the search as a loop) was already this tree's | Translator tests: all 22 files pass, `test_dmsh_raw_run.py` (the PR's, on this tree's table and signatures) included: one resolve before a run's three loads, no per-access helper left, 0 wrong of 1,536 GPU reads. Mac profile before (A13, Standard 0.75): the main colour pass 5-10 ms of GPU, 4.7-7.2 ms of it geometry, against 0.5 ms for the same draws in the depth pre-pass Taken back out in A15: this tree's resolved helper carries the whole fallback lookup (private words, site, hint, search), which Metal inlined at each of a mesh shader's ~490 resolved reads, so the 2,250 raw shaders compiled for minutes each on the Mac and their pipelines 2-6 s each on the A20 Pro (log 55); a resolved helper with its fallback out of line is open |
| A15 | A13 plus (A14's translator change taken back out: shader chain `5d4aa12fe633` again): Standard builds the whole prewarm list before the first frame (baked `DM_PSO_PREPARE=1`; `nvn_mtl.m` `warm_start` lets warm-only run the prepare step when asked) and still keeps nothing, so a new shader chain costs one long "Preparing shaders" screen instead of compiles in play; Potato's preset sets `DM_PSO_PREPARE=0` and keeps its background warm-up. The prewarm list gains the 65 task / mesh pipelines (M rows) this fork's Mac runs recorded, which Aznracer's list lacked | Log 55 (A14, Standard, 60 fps, render scale 0.6, first start on the new chain): at frame 655 six foliage mesh pipelines built on the submit thread, 2.0-2.1 s each and one 5.8 s, 16 s in one frame; no GPU fault (the in-flight work drained when the app went to the background) |

## Touch controls

The Native layout's keys follow the game's own Basic Controls page (its pause menu, `PlusMenu_00.msbt`; A12). The game has no shield button: holding ZL (Target) raises the shield, so a quick tap on ZL, which locks it held until the next tap, keeps the shield up while targeting.

| Key | The game's action | Where | Icon |
|---|---|---|---|
| Y | Attack | the large key where the right thumb rests | a sword |
| A | Actions (hold: Dash) | inward and low | a roll arrow round an "!" |
| ZR | Use Item | the arc, left | a bow |
| ZL | Target (and the shield); tap to lock | the arc, top | a fairy (gold ring and padlock while locked) |
| X | Jump | the arc, right | a winged boot |
| R | Quick Select Items | apart, top right | a ring of item slots |
| B | Put Away | small, bottom right corner | an arrow turning back |
| + / − | Open Menu / Open Map | top right, beside the menu (…) | a chest / a map scroll |
| D-pad | ← Play Ocarina, → Talk to Navi, ↓ Toggle Boots, ↑ Toggle Accessory | above the left stick; the floating stick keeps its ring 10 points clear | arrows |
| Left stick / right half | Move / Rotate Camera | floating stick on the left half; a drag on the right half | — |

## Potato (A4 to A12)

Aimed at a GPU memory peak under 5 GB, for phones with less memory. Standard peaks at 5.6 GB in Kokiri Forest, on the Mac (with the guest memory in files, as on the iPhone) as on the v3 author's iPhone (5,728 MB). There it holds about 2.1 GB of the game's memory pools the GPU reads, 2.2 GB of textures, 0.5 GB of render-target heaps and 0.2 GB of other buffers.

| Setting | On the Mac (2-minute runs to Kokiri Forest) |
|---|---|
| `DM_RENDER_SCALE=0.5` (0.6 until A10) | 0.65 alone: no memory saved (peak 5,786 MB); it is in Potato for the GPU time |
| `DM_NVN_TEX_SOFT=1` | this fork's V15 ran with it on the iPhone; not measured here |
| `DM_NVN_RT_LOSSY=1` | this fork's V15 ran with it on the iPhone; not measured here |
| `DM_NVN_GMEM_NOBIG=1` | pools 2,138 → 1,407 MB, in a run that froze for another setting |
| `DM_NVN_RES_EVICT_MB=4400` | new: the guard lets go of idle textures from 4,400 MB, without ever stopping the game |
| `DM_NVN_TEX_RECYCLE_MB=64`, `DM_NVN_ALIAS_SWEEP=600` | a smaller bin of recycled textures, unused shared textures swept sooner |
| `DM_PSO_WARM_ONLY=1` (A12; `DM_PSO_MANIFEST=off` from A5 to A11) | the prewarm fills the system's shader cache and keeps nothing |
| ~~`DM_NVN_TEX_MIP_SKIP=512`~~ | **froze the game** right after the save loaded (the main thread spinning); not in Potato |

`DM_NVN_TEX_MIP_LEVELS`, in the v3 env.txt, is read nowhere: it does nothing. From A9 Standard shares Potato's memory pool cap and large pools by chunk, and from A10 its memory housekeeping (`DM_NVN_RES_EVICT_MB`, `DM_NVN_TEX_RECYCLE_MB`, `DM_NVN_ALIAS_SWEEP`), none of Potato's quality cuts. On an A20 Pro (11.6 GB, about 8.1 GB per app) Standard peaked at 5.43 GB (log 47) and Potato at 4.87 GB (log 45).

## Building

As in the [v3 note](mighty-green-kokiri-kid.md#build), from a dump folder (`base/`, `updates/131072/`), with `G` the dump folder and `B` the build folder:

```sh
DM_DYNAMIC_FPS=1 python3 scripts/build_ipa_from_nsp.py "$G" --work-dir "$B" --keep-extracted --romfs separate \
  --allow-shader-regressions --env-file "$G/env-older-iphones.txt" -o "$G/OcarinaOfTime-A12.ipa"
```

The script needs Python 3.12 or newer (the RomFS image). From A4 the settings below are baked into the app (`--env-file`, the app's `dm/env.txt`); A1 to A3 had none. An `icon.jpg` beside the extracted game (`$B/extract/v131072/icon.jpg`) becomes the app icon. A change to `game.tsv` re-runs the shader split and the shader translation (about 25 minutes on a MacBook Air M5 for the Mac and as much for the iPhone; the Metal libraries themselves are reused).

## env.txt

The settings baked into A12 (`--env-file`). Each is the launcher's starting value and can be changed there; a line in the app's `Documents/env.txt` wins over it, and a choice saved in the launcher wins over both:

```
DM_PSO_WARM_ONLY=1
DM_NVN_RES_EVICT_MB=4400
DM_NVN_TEX_RECYCLE_MB=64
DM_NVN_ALIAS_SWEEP=600
DM_PRESET=potato
DM_FPS_TARGET=30
DM_PRESENT_SNAP=1
DM_PRESENT_UPSCALE=off
DM_NVN_TEX_MIP_SKIP=1024
DM_TEX_LAZY=2
DM_TEX_LAZY_MIN_KB=4096
DM_TEX_RELEASE=1
DM_OPMODE=0
DM_GFX_SCALE=2
DM_NVN_DISPATCH_OVERLAP=0
DM_POOL_ANON_MAX_MB=512
DM_NVN_GMEM_NOBIG=1
```

Removed on the way: `DM_NVN_RES_LIMIT_MB` (A4), `DM_NDSR=metalfx` (A9: MetalFX's spatial scaler in place of the game's upscaler left the grass shimmering), `DM_PSO_MANIFEST=off` (A12). The v3 note's env.txt is the [v3 note](mighty-green-kokiri-kid.md#envtxt)'s; the one first given with A2 had `DM_NVN_GMEM_SKIP=1`, which on the v3 author's iPhone raised the title screen's GPU time from 24 to 35 ms (20 to 30 fps).

## Open

- A8 to A13 are not yet fully tested on the iPhone (log 52 is A12). The next log shows whether long frames still build pipelines (`[longframe] ... new pipelines`), the scale the game picks (`3D scale up to frame`) and the footprint.
- The warm-only prewarm's first run after an install builds about 15,000 pipelines from scratch on one background thread: how long it takes on the phone, and how warm the phone runs meanwhile, are not measured.
- PR 1752 (A14) needs its fallback out of line before it can come back: the merged translator and its tests are kept aside (the A14 commit message names them).
- `DM_NVN_BARRIER=game` skips no pass barrier in this tree (A10), with or without the pool heaps; the cause is not found.
- LiveContainer's RAM donor ("Guest memory boost") maps 7 GB of other processes' memory at 0x7000000000 and sends large `malloc` / anonymous `mmap` calls there, the host's own tables among them: log 51 crashed copying one (`realloc_or_die` from `mtl_reg_tex`). Run without it.
- `test_env_switches` and `test_launcher_settings` fail on v3 with these commits as without them: switches from the v3 base have no rows in `docs/env_switches.tsv` (`DM_TEX_LAZY`, `DM_TEX_LAZY_MIN_KB`, `DM_WAKE_UNLOCKED`, `DM_FRAME_WG`), and `DM_PAD_THEME` is an iPhone-only setting the test does not list.
