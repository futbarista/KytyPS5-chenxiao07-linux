#!/usr/bin/env bash
# precompile-windows.ps1 under Wine, for demons-souls.sh: every shader and pipeline of the game into the static
# pipeline cache of this GPU's Linux driver, _Linux/_PipelineCache/static/<title>_<version>.bin (or .binaries),
# which the emulator looks up before compiling, and the shader prefetch inputs (.shaders). Takes an hour or more:
# the game cannot run meanwhile. An interrupted run resumes (finished shards are merged first).
#   ./precompile-linux.sh                       the game folder of demons-souls.sh
#   ./precompile-linux.sh --inputs-only         only the prefetch inputs (half a minute)
#   ./precompile-linux.sh --game "/path/to/PPSA01341-app0" [--jobs N] [--threads N] [--shards N]
# Wine and its prefix as in demons-souls.sh (WINE=..., WINEPREFIX=...). Logs: _Build/run-logs/<stamp>-precompile.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
game="" inputs_only=0 jobs=0 threads=3 shards=512
while [ $# -gt 0 ]; do
	case $1 in
		--game) game=$2; shift ;;
		--inputs-only) inputs_only=1 ;;
		--jobs) jobs=$2; shift ;;
		--threads) threads=$2; shift ;;
		--shards) shards=$2; shift ;;
		*) echo "unknown option $1"; exit 2 ;;
	esac
	shift
done
if [ -z "$game" ] && [ -f "$root/DemonsSouls-linux.txt" ]; then
	game="$(grep -v '^[[:space:]]*$' "$root/DemonsSouls-linux.txt" | head -n 1 | tr -d '\r')"
fi
[ -z "$game" ] && game="$HOME/Games/Demon's Souls/PPSA01341-app0"
[ -f "$game/sce_sys/param.json" ] || { echo "no sce_sys/param.json in $game (--game <folder>)"; exit 1; }
game_id="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8-sig")); print(d["titleId"]+"_"+d["contentVersion"])' "$game/sce_sys/param.json")" || exit 1

seeds="$root/seeds-$game_id.seeds"
[ -f "$seeds" ] || seeds="$root/_Build/static-precompile/seeds-$game_id.seeds"
[ -f "$seeds" ] || { echo "no seed file for $game_id (make it with precompile-windows.ps1 or tools/local/static-precompile/precompile.py)"; exit 1; }
recorded="$(dirname "$seeds")/recorded-$game_id.seeds"

# Wine: as demons-souls.sh.
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
command -v "$WINE" >/dev/null 2>&1 || { echo "no Wine: install Proton Experimental in Steam, or set WINE=/path/to/wine"; exit 1; }
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/kytyps5-wine}"
# Not -all: with every Wine debug channel off the emulator dies at start (exit code 253); the precompiler is the same code.
export WINEDEBUG="${WINEDEBUG:-fixme-all}"
export WINEFSYNC=1 WINEESYNC=1
winpath() { WINEDEBUG=-all "${WINE%wine}winepath" -w "$1" 2>/dev/null || printf 'Z:%s' "$(printf '%s' "$1" | tr '/' '\\')"; }

cpus=$(nproc)
[ "$jobs" -gt 0 ] || jobs=$(( (cpus + threads - 1) / threads ))
logs="$root/_Build/run-logs"; [ -d "$root/_Build" ] || logs="$root/logs"
logs="$logs/$(date +%Y%m%d-%H%M%S)-precompile"
# _Linux: the emulator's working folder under Wine. Its _PipelineCache is this driver's; the package's other data
# folders are links, so saves and the rest are the same as on Windows.
link_data() {
	local d
	for d in _SaveData _TempData _DownloadData _Textures _Build; do
		mkdir -p "$root/$d"
		[ -e "$root/_Linux/$d" ] || ln -s "../$d" "$root/_Linux/$d"
	done
}
mkdir -p "$logs" "$root/_Linux/_PipelineCache/static"
link_data
wgame="$(winpath "$game")"
claims="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null; wait; rm -rf "$claims"' EXIT

# One precompiler process, in _Linux (its _PipelineCache), at a low priority: run <name> <arguments...>.
run() {
	local name=$1; shift
	(cd "$root/_Linux" && exec nice -n 10 "$WINE" "$root/kyty_shader_precompile.exe" --game "$wgame" "$@" \
		> "$logs/$name.out.log" 2> "$logs/$name.err.log")
}
must() { local name=$1; run "$@" || { echo "$name failed; logs: $logs"; exit 1; }; }

inputs=(--seeds "$(winpath "$seeds")" --no-pipelines --threads "$cpus" --static-inputs)
echo "precompile: $seeds, $shards shards, $jobs at a time; logs $logs"
if [ $inputs_only = 1 ]; then
	must inputs "${inputs[@]}"
	echo "wrote _Linux/_PipelineCache/static/$game_id.shaders"
	exit 0
fi

begin=$(date +%s)
# A progress bar: shards done of all (the queue grows when a shard is split), time so far and left.
progress() {
	local total=$((finished + ${#running[@]} + ${#pending[@]})) elapsed=$(($(date +%s) - begin)) width=40 left=""
	[ $total -gt 0 ] || return
	local filled=$((finished * width / total))
	[ $finished -gt 0 ] && left=$(printf ', ~%d min left' $(((total - finished) * elapsed / finished / 60 + 1)))
	printf '  [%s%s] %3d%%  %d/%d shards, %d:%02d%s\n' "$(printf '%*s' $filled '' | tr ' ' '#')" \
		"$(printf '%*s' $((width - filled)) '' | tr ' ' '-')" $((finished * 100 / total)) $finished $total \
		$((elapsed / 60)) $((elapsed % 60)) "$left"
}
must merge-before --merge
pending=()
for ((i = 0; i < shards; i++)); do pending+=("$seeds|$i/$shards"); done
if [ -f "$recorded" ]; then
	count=$(( shards / 16 )); [ $count -ge 1 ] || count=1
	for ((i = 0; i < count; i++)); do pending+=("$recorded|$i/$count"); done
fi
# The shards share the pipelines they hold: one that several shards' seeds make is compiled once.
export KYTY_PRECOMPILE_CLAIMS="$(winpath "$claims")"
declare -A running=() # pid -> seedfile|shard
finished=0 split=0 shown=$begin
while [ ${#pending[@]} -gt 0 ] || [ ${#running[@]} -gt 0 ]; do
	while [ ${#pending[@]} -gt 0 ] && [ ${#running[@]} -lt $jobs ]; do
		entry=${pending[0]}; pending=("${pending[@]:1}")
		file=${entry%%|*} shard=${entry#*|}
		name="shard${shard/\//of}-$(basename "$file" .seeds)"
		run "$name" --seeds "$(winpath "$file")" --shard "$shard" --threads "$threads" &
		running[$!]=$entry
	done
	wait -n -p done_pid "${!running[@]}"; code=$?
	entry=${running[$done_pid]}; unset "running[$done_pid]"
	file=${entry%%|*} shard=${entry#*|}
	if [ $code -eq 3 ]; then
		# Too many pipelines for one shard's binaries: again as two.
		i=${shard%/*} n=${shard#*/}
		[ "$n" -lt 65536 ] || { echo "shard $shard of $file cannot be split further; logs: $logs"; exit 1; }
		pending+=("$file|$i/$((2 * n))" "$file|$((i + n))/$((2 * n))")
		split=$((split + 1))
	elif [ $code -ne 0 ]; then
		echo "shard $shard of $(basename "$file") failed (exit code $code); logs: $logs"; exit 1
	else
		finished=$((finished + 1))
	fi
	now=$(date +%s)
	if [ $((now - shown)) -ge 10 ]; then
		shown=$now
		progress
	fi
done
progress
unset KYTY_PRECOMPILE_CLAIMS
echo "  merging the shards and writing the prefetch inputs"
must merge --merge --prune
must inputs "${inputs[@]}"
cache=$(ls -t "$root/_Linux/_PipelineCache/static/$game_id".bin "$root/_Linux/_PipelineCache/static/$game_id".binaries 2>/dev/null | head -n 1)
now=$(date +%s)
printf 'done in %02d:%02d:%02d: %s (%s; %d shards split)\n' $(((now - begin) / 3600)) $(((now - begin) % 3600 / 60)) \
	$(((now - begin) % 60)) "$cache" "$(du -h "$cache" 2>/dev/null | cut -f1)" $split
