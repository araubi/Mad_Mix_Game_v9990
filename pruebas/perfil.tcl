# Perfil: partida con movimientos y muestreo de PC + marcas de tiempo
proc pulsa {t fila bit {d 0.3}} { after time $t "keymatrixdown $fila $bit"; after time [expr {$t+$d}] "keymatrixup $fila $bit" }
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
set ::perf_f [open $::env(PERF_OUT) w]
set ::perf_on 0
proc muestra {} {
  if {!$::perf_on} return
  puts $::perf_f "S [reg pc]"
  after time 0.00025 muestra
}
proc marca {tag} { if {$::perf_on} { puts $::perf_f "$tag [machine_info time]" } }
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
# escrituras en la zona $6503-$83FF, que debe seguir libre
debug set_watchpoint write_mem {0x6503 0x83FF} {} {marca X}
after time 26 { set ::perf_on 1; muestra }
after time 56 { set ::perf_on 0; close $::perf_f }
