# Demon's Souls on Linux (SteamOS): the Windows build under Wine / Proton

This branch is chenxiao07's KytyPS5 `v20261007` (`9348901`) with three files added for playing
Demon's Souls (PPSA01341) on Linux with the **Windows release** of the emulator, run by Wine or Proton.
Nothing of chenxiao07's is changed.

| File | What it does |
| --- | --- |
| `demons-souls.sh` | Starts `kyty_emulator.exe` under Wine or Proton with the switches of `run-windows.ps1`, the Linux fixes below, the Steam Input wait and the FPS counter. |
| `precompile-linux.sh` | `precompile-windows.ps1` in bash: the static shader and pipeline precompile, with `kyty_shader_precompile.exe` under Wine, for the Linux graphics driver. |
| `build-appimage.sh` | Optional: packs `demons-souls.sh` as `DemonsSouls-x86_64.AppImage` (downloads `appimagetool`). |

Tested on SteamOS (Desktop Mode, KDE Plasma Wayland), Ryzen 5 9600X, Radeon RX 9070 XT, Mesa RADV 26.1,
Proton Experimental 11.0.

## Setup

1. Unzip the Windows release (`KytyPS5-v20261007.zip`) and copy these files next to `kyty_emulator.exe`.
2. Install Proton Experimental in Steam (SteamOS has no system Wine; the scripts find Steam's Proton).
3. The game folder: `~/Games/Demon's Souls/PPSA01341-app0` by default, else its path as the first argument
   or in `DemonsSouls-linux.txt` next to the script.
4. Once, and again after a Mesa update (a SteamOS update): `./precompile-linux.sh` (about 20 minutes on 12
   threads; the game cannot run meanwhile).
5. `./demons-souls.sh`, or in Steam: *Add a Non-Steam Game* → `demons-souls.sh`. Do **not** set a
   compatibility tool for it: the script runs Wine/Proton itself.

Options (environment variables; in Steam's launch options as `NAME=value %command%`):

| Variable | Effect |
| --- | --- |
| `PROTON=1` | Proton's own launcher (Proton Experimental; `PROTON=/path/to/proton-folder` for another) instead of its `wine` binary. Prefix `~/.local/share/kytyps5-proton`. |
| `FULLSCREEN=1` | Full screen (default: a window; F11 toggles). |
| `WIDTH=3840 HEIGHT=2160` | Another resolution (default 2560x1440). |
| `FPS_HUD=0` | No frame rate panel (`KYTY_FPS_HUD`, on by default). |
| `CONSOLE_LANGUAGE=1` | Another console language (default 16, Polish; 1 is English (United States)). |
| `WINE=...`, `WINEPREFIX=...` | Another Wine / prefix (default `~/.local/share/kytyps5-wine`). |

Logs: `_Build/run-logs` (or `logs`) next to the emulator.

## What is different from Windows, and why

**`WINEDEBUG` must not be `-all`.** With every Wine debug channel off, the emulator exits about 10 s after
start with code 253, every time, right after red-zone patching `eboot.bin`; with the error channel on
(`fixme-all`, the script's default) it starts every time. Proton's launcher sets `WINEDEBUG=-all` unless
`PROTON_LOG` is set, and it writes that log only when `SteamGameId` is set: the script sets
`PROTON_LOG=1` and, outside Steam, `SteamGameId=0`.

**`KYTY_GPU_BUFFER_PAGES=0` and `KYTY_BUFFER_RECLAIM=0`.** With `GPU_BUFFER_PAGES`, `BUFFER_RECLAIM` and
`UNMAP_PROTECT_SKIP` all on (the release config), loading a save ended in a GPU page fault under RADV
(`vkQueueSubmit` -4, *Device fault ... read invalid*): the GPU read buffers over guest memory that the
emulator had destroyed seconds before. Any one of the three off avoided it in single runs, but with only
`BUFFER_RECLAIM` off it still happened now and then; with `GPU_BUFFER_PAGES` off as well, no crash in
repeated runs. It costs frame rate (about 47 → 40 fps standing still in Boletaria's Nexus), so a fix in
the emulator would be worth more than this switch.

**The static shader cache is the driver's.** `_PipelineCache/static/<title>_<version>.binaries` and
`.shaders` made on Windows belong to AMD's Windows driver; under Wine the emulator uses the Linux driver
(RADV), which rejects them (*"Shader prefetch: no inputs for this GPU and driver"*), so every pipeline was
compiled in play: dozens of frames over 100 ms and freezes of up to 10 s in a minute of walking.
`precompile-linux.sh` makes them for RADV. The emulator reads `_PipelineCache` from its working
directory, so the scripts use `_Linux/` next to it (its own `_PipelineCache`, links to `_SaveData`,
`_TempData`, `_DownloadData`, `_Textures` and `_Build`): the Windows cache stays as it was. RADV compiles
the whole game's pipelines in about 20 minutes (the Windows driver: over an hour).

**Steam Input.** Wine's HID bus enumerates devices when it starts; started by Steam, the script waits up to
5 s for Steam's virtual gamepad (28de:11ff) first.

## Not working (yet)

- The native Linux build of this commit (a third-party package built without chenxiao07's -O3 /
  ThinLTO / PGO) ran at 1–6 fps here, frames of exactly ~3 s; not investigated further.
- Frame generation: the emulator's is DLSS-G through NVIDIA Streamline (RTX 40/50 only) and this release is
  built without it. FSR 4 has no Vulkan SDK; FSR 3.1 frame generation (Vulkan) could take the same inputs
  (`src/local/frame-gen.cpp`: the game's TAA motion vectors and depth, its camera).
