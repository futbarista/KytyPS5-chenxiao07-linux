#!/usr/bin/env bash
# Demon's Souls on the Windows build of KytyPS5 under Wine or Proton: a 2560x1440 window (16:9), red-zone protection,
# Polish console language. The switches are those run-windows.ps1 gives, with the changes Wine needs (below).
#   ./demons-souls.sh                         the game folder from DemonsSouls-linux.txt next to this script,
#                                             else ~/Games/Demon's Souls/PPSA01341-app0
#   ./demons-souls.sh "/path/to/PPSA01341-app0"
#   WINE=/path/to/wine ./demons-souls.sh      another Wine (default: wine on PATH, else Steam's newest Proton)
#   WINEPREFIX=... ./demons-souls.sh          another prefix (default: ~/.local/share/kytyps5-wine)
#   PROTON=1 ./demons-souls.sh                through Proton's own launcher (Proton Experimental; PROTON=/path/to/a
#                                             Proton folder for another), prefix ~/.local/share/kytyps5-proton/pfx
#   FULLSCREEN=1 ./demons-souls.sh            full screen (default for now: a window; F11 toggles)
#   WIDTH=3840 HEIGHT=2160 ./demons-souls.sh  another resolution (default 2560x1440)
#   FPS_HUD=0 ./demons-souls.sh               no frame rate panel in the top right corner (on by default)
#   CONSOLE_LANGUAGE=1 ./demons-souls.sh      another console language (the emulator's --console-language; default
#                                             16, Polish; 1 is English (United States))
# Logs: _Build/run-logs (or logs) next to this script. Also the AppRun of DemonsSouls-x86_64.AppImage
# (build-appimage.sh): there the KytyPS5 folder is the one the AppImage is in.
set -u
if [ -n "${APPIMAGE:-}" ]; then
	root="$(cd "$(dirname "$APPIMAGE")" && pwd)"
else
	root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# A key at the end when there is a terminal to read it from (Steam starts this without one).
pause() { [ -t 0 ] && { read -n 1 -s -r -p "Press any key to close..."; echo; }; }

game="${1:-}"
if [ -z "$game" ] && [ -f "$root/DemonsSouls-linux.txt" ]; then
	game="$(grep -v '^[[:space:]]*$' "$root/DemonsSouls-linux.txt" | head -n 1 | tr -d '\r')"
fi
[ -z "$game" ] && game="$HOME/Games/Demon's Souls/PPSA01341-app0"
if [ ! -f "$game/eboot.bin" ]; then
	echo "no eboot.bin in $game (pass the game folder, or put its path in $root/DemonsSouls-linux.txt)"
	pause; exit 1
fi

# Wine: $WINE, else wine on PATH, else the newest Proton Steam has installed (SteamOS has no system Wine).
if [ -z "${WINE:-}" ]; then
	if command -v wine >/dev/null 2>&1; then
		WINE=wine
	else
		for steam in "$HOME/.steam/steam" "$HOME/.local/share/Steam" "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
			for proton in "$steam/steamapps/common/Proton - Experimental" $(ls -d "$steam"/steamapps/common/Proton* 2>/dev/null | sort -rV); do
				[ -x "$proton/files/bin/wine" ] && { WINE="$proton/files/bin/wine"; break 2; }
			done
		done
	fi
fi
if [ -z "${WINE:-}" ] || ! command -v "$WINE" >/dev/null 2>&1; then
	echo "no Wine: install Proton Experimental in Steam, or set WINE=/path/to/wine"
	pause; exit 1
fi
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/kytyps5-wine}"
# Not -all: with every Wine debug channel off the emulator dies 10 s in (exit code 253), every time.
export WINEDEBUG="${WINEDEBUG:-fixme-all}"
export WINEFSYNC=1 WINEESYNC=1
mkdir -p "$WINEPREFIX"

# The emulator's switches (run-windows.ps1 with the release config), except GPU_BUFFER_PAGES and BUFFER_RECLAIM, off
# under Wine: with GPU_BUFFER_PAGES, BUFFER_RECLAIM and UNMAP_PROTECT_SKIP on, loading a save often ended in a GPU page
# fault (vkQueueSubmit -4, RADV; the GPU read buffers over guest memory destroyed seconds before), and with
# BUFFER_RECLAIM alone off it still did now and then.
export KYTY_SHADER_WARMUP=1 KYTY_GPU_BUFFER_PAGES=0 KYTY_SRT_NATIVE=1 KYTY_SRT_PREDICATES=1 \
	KYTY_PREPARATION_SCRATCH=1 KYTY_PREPARATION_LOOKUP=1 KYTY_PREPARATION_TRIM=1 KYTY_SPECIALIZATION_GUARD=1 \
	KYTY_PIPELINE_INDEX=1 KYTY_BINDING_SCRATCH=1 KYTY_DRAW_RUN_RANGES=1 KYTY_BUFFER_RESIDENCY=1 \
	KYTY_COPY_FEEDBACK=1 KYTY_ASYNC_LOD_STATS=1 KYTY_BACKING_READ=1 KYTY_STREAM_UPLOAD=1 KYTY_FRAME_PIPELINE=1 \
	KYTY_IMAGE_BARRIER_DEDUPE=1 KYTY_IMAGE_POOL=1 KYTY_PENDING_DRAIN=1 KYTY_DISPATCH_BATCH=128 \
	KYTY_VULKAN_RECORDING=1 KYTY_DEFERRED_SUBMIT=1 KYTY_NATIVE_XPR=1 KYTY_WRITE_WINDOW_HANDOFF=1 \
	KYTY_READBACK_DETACH=1 KYTY_ASYNC_WRITE_READBACK=1 KYTY_READBACK_SLOTS=1 KYTY_ASYNC_UPLOAD=2 \
	KYTY_BDA_DIRTY_REGIONS=1 KYTY_GLOBAL_BARRIER_DEDUPE=1 KYTY_RANGE_SET_FAST=1 KYTY_IMAGE_GRANULES=2 \
	KYTY_NATIVE_XPR_PREDICT=1 KYTY_NATIVE_IMAGE_PROOF=1 KYTY_TEXTURE_RESOLVE_PAGES=1 KYTY_ASYNC_REPROTECT=1 \
	KYTY_READBACK_NARROW=1 KYTY_SHADER_WARMUP_THREADS=16 KYTY_READBACK_QUEUE=1 KYTY_TABLE_XPR=2 \
	KYTY_TABLE_DISPATCH=1 KYTY_BUFFER_RECLAIM=0 KYTY_DRAW_PACKETS=1 KYTY_PARTIAL_IMAGE_DIRTY=1 \
	KYTY_PARTIAL_ROW_BANDS=1 KYTY_ASYNC_XPR_PIPELINES=1 KYTY_NATIVE_XPR_RELOCATE=1 \
	KYTY_NATIVE_XPR_STORE_BUDGET=256 KYTY_NATIVE_XPR_KEEP_FRAMES=600 KYTY_NATIVE_XPR_INSTANCES=1 \
	KYTY_GAME_CONVARS=doIndexBufferCulling=false KYTY_UNMAP_PROTECT_SKIP=1 \
	KYTY_DRIVER_CACHE_KEY=1f3c29b70e536c8f5a5e812e793b33ac2eb6858b4810ed98ca2a51b9fa5eed97 \
	KYTY_SHADER_WARMUP_SECONDS=60 KYTY_HITCH_LOG_MS=100 KYTY_PRESENT_ASPECT=fit
unset KYTY_SHADER_WARMUP_ONLY
# The frame rate panel in the top right corner of the game image (SuperMedo's "FPS counter").
[ "${FPS_HUD:-1}" != 0 ] && export KYTY_FPS_HUD=1
fullscreen=(); [ "${FULLSCREEN:-0}" = 1 ] && fullscreen=(--fullscreen)

# Started by Steam: wait (at most 5 s) for Steam Input's virtual gamepad, so Wine's bus finds it when it starts.
if [ -n "${SteamVirtualGamepadInfo:-}" ]; then
	for _ in $(seq 50); do
		grep -qs '^28de:11ff$' <(for d in /sys/class/input/event*/device/id; do echo "$(cat "$d/vendor"):$(cat "$d/product")"; done 2>/dev/null) && break
		sleep 0.1
	done
fi

# The game folder as Wine sees it (Z: is /).
wingame="$(WINEDEBUG=-all "${WINE%wine}winepath" -w "$game" 2>/dev/null || true)"
[ -z "$wingame" ] && wingame="Z:$(printf '%s' "$game" | tr '/' '\\')"

logdir="$root/logs"; [ -d "$root/_Build" ] && logdir="$root/_Build/run-logs"
mkdir -p "$logdir"
stamp="$logdir/$(date +%Y%m%d-%H%M%S-%3N)"

# The emulator's data (_PipelineCache, _SaveData, ...) is in the folder it starts in: _Linux once precompile-linux.sh
# made it (the static precompile is for this GPU's Linux driver; the Windows one stays in the package's).
# _Linux: the emulator's working folder under Wine. Its _PipelineCache is this driver's; the package's other data
# folders are links, so saves and the rest are the same as on Windows.
link_data() {
	local d
	for d in _SaveData _TempData _DownloadData _Textures _Build; do
		mkdir -p "$root/$d"
		[ -e "$root/_Linux/$d" ] || ln -s "../$d" "$root/_Linux/$d"
	done
}
cd "$root"; [ -d _Linux/_PipelineCache ] && { link_data; cd _Linux; }
echo "game:    $game"
# PROTON: Proton's launcher instead of its wine. Without PROTON_LOG it sets WINEDEBUG=-all (the exit 253 above);
# with it, it keeps ours and writes its log (steam-<SteamGameId>.log) next to the run's.
runner=("$WINE")
if [ -n "${PROTON:-}" ]; then
	proton_dir=$PROTON; [ "$proton_dir" = 1 ] && proton_dir="$(dirname "$(dirname "$(dirname "$WINE")")")"
	[ -x "$proton_dir/proton" ] || { echo "no proton in $proton_dir"; pause; exit 1; }
	export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/.local/share/kytyps5-proton}"
	export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.local/share/Steam}"
	# Its log (and so our WINEDEBUG) needs SteamGameId, which Steam sets: 0 when started from elsewhere.
	export PROTON_LOG=1 PROTON_LOG_DIR="$logdir" SteamGameId="${SteamGameId:-0}"
	unset WINEPREFIX
	mkdir -p "$STEAM_COMPAT_DATA_PATH"
	runner=("$proton_dir/proton" waitforexitandrun)
	echo "proton:  $proton_dir ($STEAM_COMPAT_DATA_PATH)"
else
	echo "wine:    $WINE ($WINEPREFIX)"
fi
echo "logs:    $stamp.*.log"
"${runner[@]}" "$root/kyty_emulator.exe" --game "$wingame" \
	--screen-width "${WIDTH:-2560}" --screen-height "${HEIGHT:-1440}" --console-language "${CONSOLE_LANGUAGE:-16}" \
	--shader-validation false --shader-log-direction Silent --printf-direction Silent \
	--vblank-frequency 60 --present-mode Immediate "${fullscreen[@]}" --redzone \
	2> "$stamp.err.log" | tee "$stamp.out.log"
code=${PIPESTATUS[0]}

if [ "$code" -ne 0 ]; then
	echo
	echo "The game exited with code $code; logs: $stamp.*.log"
	tail -n 20 "$stamp.err.log"
	pause
fi
exit "$code"
