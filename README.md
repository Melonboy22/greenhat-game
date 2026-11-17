# greenhat-game

A personal build for playing The Legend of Zelda: Ocarina of Time (Switch 2, v131072) as a native Mac app on my own machine: a MacBook Air M5 with 16 GB of RAM and an 8-core GPU, macOS 27.2. It is built with [Hermit](https://github.com/azmasm/hermit) (formerly switch2mac) from the `oot-plus` branch: see [Or do it like I did: build it with Hermit](#or-do-it-like-i-did-build-it-with-hermit).

**Where it comes from:** built on [seedds/nxnative](https://github.com/seedds/nxnative), through [Fasen24-AI/swordboiMacNative](https://github.com/Fasen24-AI/swordboiMacNative) (the code base this build uses). The repository is a fork of [cheemu21/kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake), and some of its memory savers are ported here.

**What's changed for a 16 GB Mac:**
- Memory savers: smaller copies of large textures, lossy compression for some render targets, and less of the game's main memory pool pinned for the GPU.
- Memory safety: a gentler GPU memory guard, and a watchdog that frees memory before stopping the game.
- Fixes: missing or woven ground textures, flower-bush holes, and a few upstream rendering fixes.
- Extras: Upscaling presets (Quality / Balanced / Performance) and opt-in frame generation.

The details, measurements and what is still open are in the [game's note](dm/games/0400486024DEC000/README.md#memory).

**License:** MIT, Copyright (c) 2026 seedds, as in the original project. Changes here are made by Melonboy22 with Claude (Anthropic). No game files are included: you need your own copy of the game. Not affiliated with Nintendo.

**Where the pieces come from:**

| Project | What this build took from it |
|---|---|
| [seedds/nxnative](https://github.com/seedds/nxnative) (MIT) | The engine everything runs on. Four of its open pull requests are merged here: #2226 (holes in Hyrule Castle's flower bushes), #2249 (stale draw state), #2230 (a buffer check) and #2241 (frame generation). |
| [Fasen24-AI/swordboiMacNative](https://github.com/Fasen24-AI/swordboiMacNative) (MIT) | The base: this build starts from its commit `d57562fc`, with its lighting, terrain, GPU memory guard and Castle Town memory fixes. |
| [cheemu21/kid-with-sword-remake](https://github.com/cheemu21/kid-with-sword-remake) (MIT) | The memory savers, ported to the swordboi base: smaller copies of large textures (`tex_soft`), the retired-texture shortcut (`pool_skip_retired`), lossy render targets (`rt_lossy`) and the pool-pinning settings (`gmem_skip`, `gmem_nobig`). Its frame generation came in through #2241. This repository is a fork of it. |
| [ly05010419/MacNativeGames](https://github.com/ly05010419/MacNativeGames) (MIT) | Reviewed for Ocarina of Time fixes. It runs the game on a different engine, so no code was taken. |
| [PranavDupati/ninboy-hat-for-macos](https://github.com/PranavDupati/ninboy-hat-for-macos) (MIT) | Reviewed. A keyboard and mouse mode was adapted from it; it is off by default and not working yet. Its modified game asset was left out. |
| [azmasm/hermit](https://github.com/azmasm/hermit) (formerly switch2mac) | The app that builds and launches this build. Nothing from it is in this repository. |
| Hookshot by NotRexed (GPL-3.0) | The idea of frame generation for this game, through kid-with-sword-remake. No code was taken. |

On my own Mac I also use hotoni's Xbox-Buttons mod (GameBanana, CC BY-NC-ND) for the button icons. It is not included here.

## Games

The full [tested games table](dm/games/README.md#games) includes original Switch games, tested builds, engines and graphics APIs. Each game's note records its tested platforms, progress and known issues.

These Switch 2 games have passed Mac gameplay testing. Build them from a [`.nup` file or a dump folder](#switch-2-games):

- [Donkey Kong Bananza](dm/games/040074A01BF12000/README.md)
- [Fire Emblem Fortune's Weave](dm/games/04007EF01F8AE000/README.md) — up to 120 fps
- [Hyrule Warriors: Age of Imprisonment](dm/games/04003F40232DE000/README.md)
- [Kirby Air Riders](dm/games/040077201BE50000/README.md)
- [Mario Kart World](dm/games/0400C3F00006E000/README.md)
- [Mario Tennis Fever](dm/games/0400D4201C6EA000/README.md)
- [Pokémon Pokopia](dm/games/0400A3A01EE4C000/README.md)
- [Splatoon Raiders](dm/games/0400380020056000/README.md)
- [Star Fox](dm/games/0400E88025B1A000/README.md)
- [The Legend of Zelda: Ocarina of Time](dm/games/0400486024DEC000/README.md)
- [Yoshi and the Mysterious Book](dm/games/0400245021D2C000/README.md)

## Community front ends

Community projects build on nxnative with tools to turn your games into apps for your iPhone, iPad or Mac without the command line, and libraries to organize and launch them. They are separate projects: questions and bugs about them go to their own pages.

- [NX2Apple](https://github.com/LNPANDY/NX2Apple) — Mac builder with a shared iPhone/iPad game library.
- [NX Play](https://github.com/varyform/nx-native-wrapper) — Mac library with device installs and save sync.
- [NxNative Launcher](https://github.com/rennan101/nxnative_Launcher) — Mac launcher with guided builds and controller mapping.
- [LumaNX](https://github.com/Xc1Ym/LumaNX) — Mac game builder with IPA export.
- [GameCase](https://github.com/Tiaoge-tou/GameCase) — iOS game library based on LiveContainer.

## Requirements

- **Mac:** Apple silicon, macOS 26.6 or later. Building games requires Xcode 27.2.
- **iPhone:** A17 Pro chip or later, with iOS 26 or later.
- **iPad:** M1 chip or later, with iPadOS 26 or later.

The games' textures are BC-compressed, which older iPhones cannot read. Switch 2 builds are tested on the Mac; check each game's note for device-specific validation.

For a game without a profile, the script writes a survey and tries a provisional build with guessed settings. That build may not start; see [Port another game](docs/development.md#port-another-game).

## How to play

Switch 2 games are built from one `.nup` file or a folder of their files, not from NSPs, and are tested on the Mac only: see [Switch 2 games](#switch-2-games).

### Build from the command line

You need a Mac with macOS 26.6 or later, [Xcode](https://developer.apple.com/download/all/?q=Xcode%2027.2) 27.2, [Homebrew](https://brew.sh) and Python 3.12 or newer (an arm64 one, not an Intel Homebrew's). An iPhone build also needs Xcode's iOS platform (Xcode → Settings → Components).

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
python3 scripts/build_ipa_from_nsp.py ~/Games/MarioWonder -k ~/keys/prod.keys
```

The IPA appears in the game's folder. The first build takes 30–60 minutes and needs free disk space of about twice the game's size plus 10 GB; building again is much faster.

To play on the Mac instead, add `--platform mac-app`: you get a Mac app of the game to open from Finder. All options: [The packing script in detail](docs/development.md#the-packing-script-in-detail).

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

### Install

Install the IPA on your iPhone or iPad with a sideloading tool such as AltStore, Sideloadly or LiveContainer. If your tool offers **Increased Memory Limit**, turn it on: the bigger games need it.

Game too big to install? Build again with `--romfs separate`, and run the command the script prints once to copy the game files to your phone ([Quick reinstalls](docs/development.md#quick-reinstalls)). With AltServer, also add `--shader-files`: it cannot install a file of 2 GiB or more.

Controls, saves and settings: [Playing](docs/playing.md).

### Switch 2 games

A Switch 2 game is built from one [NUP](https://github.com/a55uka/nup) container (a `.nup` file) or a folder of its files, not from NSPs. Neither needs `prod.keys`. A game this project has no profile for is surveyed and gets a provisional profile, as NSPs do ([Port another game](docs/development.md#port-another-game)), which may not boot. You get a Mac app; iPhone and iPad are untested.

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

Questions, how a game runs on your Mac or iPhone, and ideas go in [Discussions](https://github.com/seedds/nxnative/discussions); [Issues](https://github.com/seedds/nxnative/issues) are for bugs, with the log. Ocarina of Time's performance (frame rate, resolution, which Macs hold 60 fps) is followed in [Ocarina of Time: state on main](https://github.com/seedds/nxnative/discussions/1789).

## For developers

[How it works](docs/development.md) · [Game notes](dm/games/README.md#games) · [Bring-up and debugging](docs/agents/README.md) · [Front ends](docs/frontends.md) · [Contributing](CONTRIBUTING.md)

## Acknowledgements

This project is built on other people's work ([licenses](dm/third_party/README.md)):

- **[d2r-mobile](https://github.com/jhaizhou-ops/d2r-mobile)** (MIT) developed this native-execution approach, for Diablo II: Resurrected. nxnative started as a copy of its generic parts: the NSO rewriter, the host that stands in for Horizon, the NVN-on-Metal layer and the iOS app shell. Fixes go both ways.
- **Ryujinx** (MIT): its shader translator (`Ryujinx.Graphics.Shader`, `Ryujinx.Common` and `Spv.Generator` 1.3.2, in `dm/third_party/ryujinx` with a few fixes listed in [its README](dm/third_party/ryujinx/README.md)) turns the games' shaders into SPIR-V. Its emulation of the kernel and system services is also a reference when the host's behaviour is in doubt.
- **[Atmosphère](https://github.com/Atmosphere-NX/Atmosphere)**: its kernel, mesosphère, is the reference for Horizon's synchronization semantics (address arbiter, condition variables).
- **[LibHac](https://github.com/Thealexbarney/LibHac)**: reads NSPs and layers updates over the base game in `dm/tools/nx_extract`.
- **[SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross)**: SPIR-V to Metal Shading Language.
- **[glslang](https://github.com/KhronosGroup/glslang)** compiles the GLSL of OpenGL games to SPIR-V for it.
- **[MacNativeGames](https://github.com/ly05010419/MacNativeGames)** (MIT): the GPU widening of 8-bit indices and in-pass clears in `dm/gfx/nvn/nvn_mtl.m`, and the visibility-counter lowering in the shader translator.
- **Claude** (Anthropic) contributed to the greenhat-game build: the ports of kid-with-sword-remake's memory savers onto this host, the `t_tex_soft` test, and the merges of the upstream pull requests above (commits marked `Co-Authored-By: Claude`).

## License

MIT ([LICENSE](LICENSE)). Third-party code keeps its own license ([dm/third_party](dm/third_party/README.md)).
