#!/bin/bash
# perfil.sh <rom> <maquina> <salida.txt> [marcas]  -- partida de 30 s con perfil (ver perfil.tcl)
DIR=$(dirname "$(readlink -f "$0")")
PERF_OUT=$(readlink -m "$3") PERF_BP="${4:-}" MSX_MACHINE="$2" MSX_TCL="$DIR/perfil.tcl" \
  "$DIR/msxshot.sh" "$1" $(( ${PERF_T0:-26} + ${PERF_DUR:-30} + 1 )) "${3%.txt}.png" MSX ASCII16
