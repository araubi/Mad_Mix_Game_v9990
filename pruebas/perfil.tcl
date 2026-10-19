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
debug set_bp 0x9078 {} {marca L}
debug set_bp 0x882A {} {marca I}
debug set_bp 0x89A0 {} {marca W}
debug set_bp 0x8891 {} {marca V}
debug set_bp 0x88CB {} {marca C}
debug set_bp 0x8930 {} {marca E}
debug set_bp 0x8882 {} {marca g}
after time 26 { set ::perf_on 1; muestra }
after time 56 { set ::perf_on 0; close $::perf_f }
