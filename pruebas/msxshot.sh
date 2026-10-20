#!/bin/bash
# msxshot.sh <rom> <seconds> <out.png> [videosource] [romtype]
#   Boots C-BIOS_MSX1 + GFX9000 with <rom> in cartridge slot A, runs <seconds>
#   of emulated time, saves a raw screenshot to <out.png> and quits.
#   videosource: MSX | GFX9000 | Video9000 (default: openMSX default = Video9000)
#   romtype:     e.g. ASCII16, ASCII8, Konami, KonamiSCC, Mirrored, Normal ...
# Env: MSX_MACHINE (default C-BIOS_MSX1), MSX_EXTRA_ARGS (extra openmsx args),
#      MSX_SIN_GFX9000=1 (no GFX9000 cartridge),
#      MSX_SHOTS="t1 t2 ..." extra screenshots at those times (<out>_<t>.png),
#      MSX_TCL=file  extra Tcl sourced at startup (e.g. key presses).
set -euo pipefail
if [ $# -lt 3 ]; then
  sed -n '2,10p' "$0"; exit 1
fi
ROM=$(readlink -f "$1"); SECS=$2; OUT=$(readlink -m "$3"); VS=${4:-}; RT=${5:-}
OPENMSX=${OPENMSX:-$(command -v openmsx || echo /opt/openMSX/bin/openmsx)}
MACHINE=${MSX_MACHINE:-C-BIOS_MSX1}
[ -d /home/claude/local/lib ] && export LD_LIBRARY_PATH=/home/claude/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export LIBGL_ALWAYS_SOFTWARE=1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# private home so persistent settings don't leak between runs
export OPENMSX_HOME="$TMP/home"; mkdir -p "$OPENMSX_HOME"
rm -f "$OUT"

# Tcl helper: switch video source (if requested), turn throttle on for a few
# frames (with throttle off frames are skipped and screenshots come out black),
# take the screenshot, then continue / quit.
{
  echo 'set save_settings_on_exit off'
  echo 'catch {set mute on}'
  echo 'set throttle off'
  echo 'after realtime 240 {message "msxshot: watchdog timeout"; exit}'
  echo "proc msxshot_vs {} {"
  if [ -n "$VS" ]; then
    echo "  if {[catch {set ::videosource $VS} e]} {message \"msxshot: \$e\"}"
  fi
  echo "}"
  echo 'proc msxshot_take {file quit} {'
  echo '  msxshot_vs; set ::throttle on'
  echo '  after time 0.1 [list msxshot_take2 $file $quit]'
  echo '}'
  echo 'proc msxshot_take2 {file quit} {'
  echo '  if {[catch {screenshot -raw $file} e]} {message "msxshot: $e"}'
  echo '  if {$quit} {exit} else {set ::throttle off}'
  echo '}'
  for t in ${MSX_SHOTS:-}; do
    echo "after time $t {msxshot_take {${OUT%.png}_$t.png} 0}"
  done
  echo "after time $SECS {msxshot_take {$OUT} 1}"
  if [ -n "${MSX_TCL:-}" ]; then echo "source {$(readlink -f "$MSX_TCL")}"; fi
} > "$TMP/shot.tcl"

ROMARGS=(-carta "$ROM")
EXT=(-ext gfx9000); [ -n "${MSX_SIN_GFX9000:-}" ] && EXT=()
[ -n "$RT" ] && ROMARGS+=(-romtype "$RT")

timeout 300 xvfb-run -a -s "-screen 0 1024x768x24 +extension GLX" \
  "$OPENMSX" -machine "$MACHINE" "${EXT[@]}" "${ROMARGS[@]}" \
  ${MSX_EXTRA_ARGS:-} -script "$TMP/shot.tcl" > "$TMP/log" 2>&1 || true
grep -v "dsp: No such audio device" "$TMP/log" | grep -E "msxshot|rror|arning" >&2 || true
if [ -f "$OUT" ]; then
  echo "OK $OUT"
else
  echo "FAILED (no screenshot). openMSX log:" >&2; cat "$TMP/log" >&2; exit 2
fi
