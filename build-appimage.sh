#!/usr/bin/env bash
# Builds DemonsSouls-x86_64.AppImage from demons-souls.sh (its AppRun), next to this script. Run it once on
# Linux (SteamOS: from Konsole in Desktop Mode); it downloads appimagetool on the first run.
# Keep the AppImage in this folder: it starts kyty_emulator.exe from the folder it is in.
set -eu
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$root/_appimage"
tool="$work/appimagetool-x86_64.AppImage"
app="$work/DemonsSouls.AppDir"

mkdir -p "$work"
if [ ! -x "$tool" ]; then
	echo "downloading appimagetool"
	curl -fL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
	chmod +x "$tool"
fi

rm -rf "$app"
mkdir -p "$app"
sed 's/\r$//' "$root/demons-souls.sh" > "$app/AppRun"
chmod +x "$app/AppRun"
cat > "$app/demons-souls.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Demon's Souls (KytyPS5)
Exec=AppRun
Icon=demons-souls
Categories=Game;
Terminal=false
EOF
cat > "$app/demons-souls.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="40" fill="#14110f"/>
  <path d="M128 36 L150 110 L128 220 L106 110 Z" fill="#c9a24a"/>
  <rect x="78" y="100" width="100" height="14" rx="4" fill="#c9a24a"/>
</svg>
EOF

# Without FUSE (SteamOS may lack libfuse2): the tool unpacks itself and runs.
ARCH=x86_64 "$tool" --appimage-extract-and-run "$app" "$root/DemonsSouls-x86_64.AppImage"
chmod +x "$root/DemonsSouls-x86_64.AppImage"
echo "made $root/DemonsSouls-x86_64.AppImage"
