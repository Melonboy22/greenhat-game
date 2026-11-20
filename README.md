# greenhat-game

A personal build for playing The Legend of Zelda: Ocarina of Time (Switch 2, v131072) as a native Mac app on my own machine: a MacBook Air M5 with 16 GB of RAM and an 8-core GPU, macOS 27.2. It is built with [Hermit](https://github.com/azmasm/hermit) (formerly switch2mac) from the `oot-plus` branch: see [Or do it like I did: build it with Hermit](#or-do-it-like-i-did-build-it-with-hermit).

**Where it comes from:** built on [seedds/nxnative](https://github.com/seedds/nxnative), through [Fasen24-AI/swordboiMacNative](https://github.com/Fasen24-AI/swordboiMacNative) (the code base this build uses). The repository is a fork of [cheemu21/kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake), and some of its memory savers are ported here.

**What's changed for a 16 GB Mac:**
- Memory savers: smaller copies of large textures, lossy compression for some render targets, and less of the game's main memory pool pinned for the GPU.
- Memory that no longer piles up (November 2026):
  - Textures the game has finished with are let go once nothing has used them for about 4 seconds, instead of being kept in a list of 32,768. In a long session that list had grown to 1.8 GB.
  - When the game frees a block of memory, the textures made in it go too. The shadow map's 288 MB block used to stay through all of Hyrule Field.
  - Scratch memory for drawing commands is shared between frames, and spare blocks are released once idle.
  - Render targets that change size at one spot share their pool's memory, instead of each spot getting a heap of its own. That was 0.4–2.5 GB of extra heaps, docked at 1440p.
- Memory safety: a gentler GPU memory guard, and a watchdog that frees memory before stopping the game.
- Fixes: missing or woven ground textures, flower-bush holes, a black window when a smaller Resolution was picked in handheld mode, and a few upstream rendering fixes.
- Extras: Upscaling presets that show the resolution the 3D is drawn at (Quality about 965p, Balanced about 835p, Performance 720p, in a 1440p frame), a 1280 × 720 Resolution for docked play, and opt-in frame generation.

**How it runs now** (`378296c2`, on battery, Low Power Mode off):

| Area | Average fps | Lowest fps | Memory | GPU memory |
|---|---|---|---|---|
| Lon Lon Ranch | 60 | 60 | 9.2 GB | 5.7 GB |
| Hyrule Field | 59.8 | 58.6 | 9.8–10.6 GB | 5.4–6.0 GB |
| Castle Town | 57.7 | 52.4 | 10.4–10.8 GB | 5.7–5.9 GB |

- Lowest fps is the lowest 5-second average.
- Changing areas still pauses for about 0.2–0.3 s.
- Peak memory 11.2 GB, with no memory warnings.
- Low Power Mode about doubles the GPU's frame time.

The details, measurements and what is still open are in the [game's note](dm/games/0400486024DEC000/README.md#memory).

**License:** MIT, Copyright (c) 2026 seedds, as in the original project. Changes here are made by Melonboy22 with Claude (Anthropic). No game files are included: you need your own copy of the game. Not affiliated with Nintendo.

**Where the pieces come from:**

| Project | What this build took from it |
|---|---|
| [seedds/nxnative](https://github.com/seedds/nxnative) (MIT) | The engine everything runs on. Four of its open pull requests are merged here: #2226 (holes in Hyrule Castle's flower bushes), #2249 (stale draw state), #2230 (a buffer check) and #2241 (frame generation). Three of its later memory changes are ported and adapted: finished textures kept only while in use (`034e91a8`, here with a 4-second idle time instead of half a second), a freed memory pool ending its textures (`13c35e90`), and idle scratch-memory blocks released (`3fe574df`, #2862). Its release of drawn-over render targets (`8653238e`) was not taken: the swordboi base's per-pool heaps already hold them. |
| [Fasen24-AI/swordboiMacNative](https://github.com/Fasen24-AI/swordboiMacNative) (MIT) | The base: this build starts from its commit `d57562fc`, with its lighting, terrain, GPU memory guard and Castle Town memory fixes. |
| [cheemu21/kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake) (MIT) | The memory savers, ported to the swordboi base: smaller copies of large textures (`tex_soft`), the retired-texture shortcut (`pool_skip_retired`), lossy render targets (`rt_lossy`) and the pool-pinning settings (`gmem_skip`, `gmem_nobig`). Its frame generation came in through #2241. Its `ff` branch was reviewed in November 2026: 64 spare texture-table buffers instead of 16 (FF10) were taken; its iPhone and launcher work was not. This repository is a fork of it. |
| [ly05010419/MacNativeGames](https://github.com/ly05010419/MacNativeGames) (MIT) | Reviewed for Ocarina of Time fixes. It runs the game on a different engine, so no code was taken. |
| [PranavDupati/ninboy-hat-for-macos](https://github.com/PranavDupati/ninboy-hat-for-macos) (MIT) | Reviewed. A keyboard and mouse mode was adapted from it; it is off by default and not working yet. Its modified game asset was left out. |
| [azmasm/hermit](https://github.com/azmasm/hermit) (formerly switch2mac) | The app that builds and launches this build. Nothing from it is in this repository. |
| Hookshot by NotRexed (GPL-3.0) | The idea of frame generation for this game, through kid-with-sword-remake. No code was taken. |

On my own Mac I also use hotoni's Xbox-Buttons mod (GameBanana, CC BY-NC-ND) for the button icons. It is not included here.

## Community front ends

Community projects build on nxnative with tools to turn your games into Mac apps without the command line, and libraries to organize and launch them. They are separate projects: questions and bugs about them go to their own pages.

- [Hermit](https://github.com/azmasm/hermit) (formerly switch2mac) — Mac app that builds and installs games from your dump, with a game library and a pick of builds per game; what I use to build this one ([how](#or-do-it-like-i-did-build-it-with-hermit)).
- [NX2Apple](https://github.com/LNPANDY/NX2Apple) — Mac builder with a shared game library.
- [NX Play](https://github.com/varyform/nx-native-wrapper) — Mac library with device installs and save sync.
- [NxNative Launcher](https://github.com/rennan101/nxnative_Launcher) — Mac launcher with guided builds and controller mapping.
- [LumaNX](https://github.com/Xc1Ym/LumaNX) — Mac game builder.

## Requirements

This build is made for one Mac, mine, and that is the only one it has been played on:

| | My Mac |
|---|---|
| Model | MacBook Air (Mac17,3) |
| Chip | Apple M5: 10-core CPU (4 performance, 6 efficiency), 8-core GPU, Metal 4 |
| Memory | 16 GB |
| Display | Built-in, 2560 x 1664 |
| macOS | 27.2.1 |
| Build tools | Xcode 27.2 with its Metal Toolchain, .NET SDK 10.0.403, Python 3.15 |

What you need to build and play it:

- **An Apple silicon Mac.** Other M-series chips should work, but I have not tried them. Hermit itself needs macOS 26 or later.
- **16 GB of memory or more.** 16 GB is what this branch is tuned for: its memory settings aim to keep the game under about 13 GB, and its watchdog starts freeing memory at 11 GB. Quit other apps (browsers especially) before you play. More memory gives it room to spare.
- **About 110 GB of free disk for the first build.** On my Mac: the dump is 24 GB, Hermit's build folder 50 GB and the finished app 36 GB.
- **Your own dump** of The Legend of Zelda: Ocarina of Time for Switch 2 with update v131072: a folder with `base/` and `updates/131072/`, or a `.nup`. A Switch 2 game needs no keys.
- **Xcode, its Metal Toolchain and the .NET 10 SDK.** Hermit's setup checks for them and tells you what is missing.
- **A controller** (Xbox, PlayStation or Switch Pro) or the keyboard. The mouse does nothing in this build.

I play at the Quality upscaling preset (render scale 0.67) with sharpening at 0.3, Resolution on the game's own (1440p). Higher Resolutions need more memory than a 16 GB Mac has to spare with this game: at 4K docked it reached 13 GB and dropped frames. Lower ones look soft and gained no frame rate on my Mac, which is held back by the CPU side, not the GPU. The Resolution setting only applies docked.

## How to play

Switch 2 games are built from one `.nup` file or a folder of their files, not from NSPs, and are tested on the Mac only: see [Switch 2 games](#switch-2-games).

### Build from the command line

You need a Mac with macOS 26.6 or later, [Xcode](https://developer.apple.com/download/all/?q=Xcode%2027.2) 27.2, [Homebrew](https://brew.sh) and Python 3.12 or newer (an arm64 one, not an Intel Homebrew's).

The shaders are built with Xcode 27.2's Metal compiler. Select it before step 1: `sudo xcode-select -s /Applications/Xcode.app`. With several Xcode versions installed, name this one `Xcode-27.2.app` and select it with `sudo xcode-select -s /Applications/Xcode-27.2.app`.

**1. Install the tools** (only once), in Terminal:

```
xcodebuild -downloadComponent MetalToolchain
git clone https://github.com/seedds/nxnative.git && cd nxnative
brew install xcodegen zstd glslang
brew install --cask dotnet-sdk
python3 -m pip install lz4 "capstone>=5,<6" fonttools nsz zbic "backports.zstd; python_version < '3.14'"
```

**2. Put your game in a folder**: the game, plus its update and DLC if you have them (`.nsp`, `.xci`, `.nsz` or `.xcz`):

```
~/Games/MarioWonder/
  Super Mario Bros. Wonder [010015100B514000][v0].nsp
  Super Mario Bros. Wonder [010015100B514800][v327680].nsp
```

**3. Build**, with your game folder and your `prod.keys`:

```
python3 scripts/build_ipa_from_nsp.py ~/Games/MarioWonder -k ~/keys/prod.keys --platform mac-app
```

You get a Mac app of the game to open from Finder. The first build takes 30–60 minutes and needs free disk space of about twice the game's size plus 10 GB; building again is much faster. All options: [The packing script in detail](docs/development.md#the-packing-script-in-detail).

### Or do it like I did: build it with Hermit

[Hermit](https://github.com/azmasm/hermit) (formerly switch2mac) is a Mac app that builds a game from your own dump and installs it in Applications. This is how I build this repository's `oot-plus` branch:

1. **Install Hermit.** Download the latest `Hermit-<version>.pkg` from its [Releases](https://github.com/azmasm/hermit/releases/latest) and open it. It is not signed with a paid Apple Developer ID, so allow it once: System Settings → Privacy & Security → **Open Anyway**.
2. **Finish its setup.** Hermit checks your Mac and tells you what to install: Xcode (with its Metal Toolchain) and the .NET 10 SDK.
3. **Choose your game.** Press **+ Build game** and pick your Ocarina of Time dump: a folder with `base/` and `updates/131072/`, or a `.nup` file.
4. **Point it at this branch.** In the **Build** menu, choose **Your own build…** and paste:

   ```
   https://github.com/Melonboy22/greenhat-game@oot-plus
   ```

5. **Build.** Press **Build** and wait: the first build can take hours and needs plenty of free disk. The game lands in Applications. Its first start waits 1-3 minutes with no window while macOS checks the new app: don't open it twice.

Hermit marks a build from your own link as untested. In the game, **1** shows the performance overlay and **2** the settings.

The same from Terminal, with Hermit's script instead of the app:

```bash
git clone https://github.com/azmasm/hermit.git && cd hermit
./hermit.py setup
./hermit.py build "/path/to/your/dump" --custom https://github.com/Melonboy22/greenhat-game@oot-plus --engine custom
./hermit.py install
```

### Switch 2 games

A Switch 2 game is built from one [NUP](https://github.com/a55uka/nup) container (a `.nup` file) or a folder of its files, not from NSPs. Neither needs `prod.keys`. A game this project has no profile for is surveyed and gets a provisional profile, as NSPs do ([Port another game](docs/development.md#port-another-game)), which may not boot. You get a Mac app.

**From a `.nup` file**, which holds the base game, its updates and DLC in one file. Give the file, or a folder that holds it:

```
python3 scripts/build_ipa_from_nsp.py ~/Games/DonkeyKongBananza.nup --platform mac-app
```

[Hyrule Warriors: Age of Imprisonment](dm/games/04003F40232DE000/README.md) is played this way: its 47 GB NUP unpacks in under five minutes. A NUP that carries the game's control data (its NACP) and icon gives the app the game's name and icon; otherwise the name comes from the game's profile and the app has no icon unless you give it one with `--icon <image>` (`ICON` in Spyder; a JPEG or PNG of any size).

A NUP without the base game also works, when its base package is empty or it has none and its updates are marked `standalone_update`: the update is taken as the whole game, and the script says so. If the game then stops on missing files, that update holds only what changed: pack a NUP with the base game. The newest update is selected by default; `--package v<N>` selects another version in the container. Such a container has no `v0` (base game) to select.

**From a folder of files**. The script expects this layout (`updates` and `dlc` are optional):

```
~/Games/DonkeyKongBananza/
  base/exefs/                     main, main.npdm, sdk, rtld
  base/romfs/
  updates/458752/exefs/           the update's version, as a decimal number
  updates/458752/romfs/           the patched RomFS, not a patch
  dlc/040074a01bf13001/0/romfs/   the DLC's title ID
```

```
python3 scripts/build_ipa_from_nsp.py ~/Games/DonkeyKongBananza --platform mac-app
```

An update's folder alone will do (no `base/`), and so will `exefs/` and `romfs/` directly in the folder, as `nup extract` writes them, which count as `base/`. The app has no icon, because the folder holds none; `--icon <image>` (`ICON` in Spyder) gives it one. To turn such a folder into a NUP: `nup pack ~/Games/DonkeyKongBananza game.nup`.

## Discussions

Questions, how a game runs on your Mac, and ideas go in [Discussions](https://github.com/seedds/nxnative/discussions); [Issues](https://github.com/seedds/nxnative/issues) are for bugs, with the log. Ocarina of Time's performance (frame rate, resolution, which Macs hold 60 fps) is followed in [Ocarina of Time: state on main](https://github.com/seedds/nxnative/discussions/1789).

## For developers

[How it works](docs/development.md) · [Game notes](dm/games/README.md#games) · [Bring-up and debugging](docs/agents/README.md) · [Front ends](docs/frontends.md) · [Contributing](CONTRIBUTING.md)

## Acknowledgements

This project is built on other people's work ([licenses](dm/third_party/README.md)):

- **[d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile)** (MIT) developed this native-execution approach, for Diablo II: Resurrected. nxnative started as a copy of its generic parts: the NSO rewriter, the host that stands in for Horizon, and the NVN-on-Metal layer. Fixes go both ways.
- **Ryujinx** (MIT): its shader translator (`Ryujinx.Graphics.Shader`, `Ryujinx.Common` and `Spv.Generator` 1.3.2, in `dm/third_party/ryujinx` with a few fixes listed in [its README](dm/third_party/ryujinx/README.md)) turns the games' shaders into SPIR-V. Its emulation of the kernel and system services is also a reference when the host's behaviour is in doubt.
- **[Atmosphère](https://github.com/Atmosphere-NX/Atmosphere)**: its kernel, mesosphère, is the reference for Horizon's synchronization semantics (address arbiter, condition variables).
- **[LibHac](https://github.com/Thealexbarney/LibHac)**: reads NSPs and layers updates over the base game in `dm/tools/nx_extract`.
- **[SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)**: SPIR-V to Metal Shading Language.
- **[glslang](https://github.com/KhronosGroup/glslang)** compiles the GLSL of OpenGL games to SPIR-V for it.
- **[MacNativeGames](https://github.com/ly05010419/MacNativeGames)** (MIT): the GPU widening of 8-bit indices and in-pass clears in `dm/gfx/nvn/nvn_mtl.m`, and the visibility-counter lowering in the shader translator.
- **Claude** (Anthropic) contributed to the greenhat-game build: the ports of kid-with-sword-remake's memory savers onto this host, the `t_tex_soft` test, and the merges of the upstream pull requests above (commits marked `Co-Authored-By: Claude`).

## License

MIT ([LICENSE](LICENSE)). Third-party code keeps its own license ([dm/third_party](dm/third_party/README.md)).
