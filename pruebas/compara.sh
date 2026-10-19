#!/bin/bash
# compara.sh <romA> <romB> <maquina> -- juega la misma partida (perfil.tcl, sin perfil) con
# las dos ROM y compara capturas en los mismos instantes. Imprime los instantes distintos.
DIR=$(dirname "$(readlink -f "$0")"); T="22 26 30 34 38 42 46 50 54"
TMP=$(mktemp -d)
for r in A B; do
  rom=$1; [ $r = B ] && rom=$2
  PERF_OUT=/dev/null MSX_MACHINE=$3 MSX_TCL="$DIR/perfil.tcl" MSX_SHOTS="$T" \
    "$DIR/msxshot.sh" "$rom" 56 "$TMP/$r.png" MSX ASCII16 >/dev/null
done
dif=0
for t in $T; do
  n=$(compare -metric AE "$TMP/A_$t.png" "$TMP/B_$t.png" null: 2>&1)
  [ "$n" != "0" ] && { echo "t=$t: $n pixeles distintos"; dif=1; }
done
[ $dif = 0 ] && echo "IDENTICAS en $T"
cp "$TMP"/*_54.png . 2>/dev/null; rm -rf "$TMP"
