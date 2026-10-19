# Perfil: partida con movimientos y muestreo de PC + marcas de tiempo
proc pulsa {t fila bit {d 0.3}} { after time $t "keymatrixdown $fila $bit"; after time [expr {$t+$d}] "keymatrixup $fila $bit" }
# PERF_MODO=demo: menu -> 4 DEMO (entrada grabada, misma partida a cualquier velocidad)
if {[info exists ::env(PERF_MODO)] && $::env(PERF_MODO) eq "demo"} {
  pulsa 15 8 0x01
  pulsa 17 0 0x10
} else {
pulsa 15 8 0x01
  pulsa 17 0 0x02
  pulsa 18 0 0x01
  # derecha, abajo, izquierda, arriba en bucle desde t=24
  set t 24
  for {set i 0} {$i < 6} {incr i} {
    pulsa $t 4 0x20 1.6; set t [expr {$t+1.7}]
    pulsa $t 2 0x40 1.6; set t [expr {$t+1.7}]
    pulsa $t 4 0x10 1.6; set t [expr {$t+1.7}]
    pulsa $t 4 0x40 1.6; set t [expr {$t+1.7}]
  }
}
set ::perf_f [open $::env(PERF_OUT) w]
set ::perf_on 0
proc muestra {} {
  if {!$::perf_on} return
  puts $::perf_f "S [reg pc]"
  after time 0.00025 muestra
}
# huella de la parte visible de BUFFER_LOSETAS_TRABAJO: 144 lineas x 24 bytes
# (los bytes 0-3 y 28-31 de cada linea de 32 no se dibujan nunca)
proc huella_buffer {} {
  set d ""
  for {set y 0} {$y < 144} {incr y} {
    append d [debug read_block memory [expr {0xDE04 + 32*$y}] 24]
  }
  return [zlib crc32 $d]
}
proc marca {tag} {
  if {!$::perf_on} return
  puts $::perf_f "$tag [machine_info time]"
  # PERF_HASH=1: en cada tic (marca L), huella del estado del juego
  # (variables $2B00-$2DFF, matriz del nivel $FC50-$FFEF y BUFFER_LOSETAS_TRABAJO)
  if {$tag eq "L" && [info exists ::env(PERF_HASH)]} {
    puts $::perf_f "H [zlib crc32 [debug read_block memory 0x2B00 0x300]] [zlib crc32 [debug read_block memory 0xFC50 0x3A0]] [huella_buffer]"
  }
}
# marcas: PERF_BP="L:0x9078 I:0x882A ..." (por defecto, las de la version F0)
set bps "L:0x9078 I:0x882A W:0x89A0 V:0x8891 C:0x88CB E:0x8930 g:0x8882"
if {[info exists ::env(PERF_BP)] && $::env(PERF_BP) ne ""} { set bps $::env(PERF_BP) }
foreach bp $bps {
  lassign [split $bp :] tag addr
  debug set_bp $addr {} [list marca $tag]
}
# accesos a VRAM demasiado rapidos para el TMS9918 (como en el hardware real)
set too_fast_vram_access real
proc vram_rapida {args} { marca R }
set VDP.too_fast_vram_access_callback vram_rapida
# escrituras en la zona libre que queda tras optimizaciones.asm
# (PERF_LIBRE="desde hasta"; por defecto el final del codigo nuevo)
set libre {0x6C00 0x83FF}
if {[info exists ::env(PERF_LIBRE)]} { set libre $::env(PERF_LIBRE) }
debug set_watchpoint write_mem $libre {} {marca X}
# ventana de medida: PERF_T0 (por defecto 26 s) y PERF_DUR (30 s)
set t0 26; set dur 30
if {[info exists ::env(PERF_T0)]} { set t0 $::env(PERF_T0) }
if {[info exists ::env(PERF_DUR)]} { set dur $::env(PERF_DUR) }
after time $t0 { set ::perf_on 1; muestra }
after time [expr {$t0 + $dur}] { set ::perf_on 0; close $::perf_f }
