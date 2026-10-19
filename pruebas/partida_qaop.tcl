proc pulsa {t fila bit {d 0.3}} { after time $t "keymatrixdown $fila $bit"; after time [expr {$t+$d}] "keymatrixup $fila $bit" }
pulsa 15 8 0x01
pulsa 17 0 0x02
pulsa 18 0 0x01
pulsa 24 4 0x20 3
pulsa 27.2 2 0x40 3
pulsa 30.4 4 0x10 3
