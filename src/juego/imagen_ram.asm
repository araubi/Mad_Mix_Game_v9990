; ==============================================================
;  imagen_ram.asm -- Mad Mix Game v9990
;
;  Ensambla el juego en sus direcciones NATIVAS de RAM (las mismas
;  que deja en memoria el cargador de cinta original) y vuelca cada
;  tramo a un binario plano que luego empaqueta la ROM:
;
;    build/ram_1000.bin   $1000-$64FF  (cuerpo de MADMIX.SCR)
;    build/ram_6500.bin   $6500-...    (codigo nuevo: optimizaciones.asm y v9990.asm)
;    build/ram_8400.bin   $8400-$DDA0  (motor, MADMIX1.BIN)
;    build/ram_0100.bin   $0100-...    (V9990 con los graficos del remake, v9990_ext.asm)
;    build/logotopo.bin   $9470-...    (logo animado de Topo, cinta)
;
;  Base: reconstruccion por ingenieria inversa de Rafael Eduardo
;  Martin Candial (github.com/raemca/MSX_MadMixGame, CC BY-NC-SA 4.0).
;  Cambios de este proyecto respecto a la v1.0: los de la v2.0 de
;  Manuel Pazos (buffer de nivel $FC50, ya aplicado en la base, y
;  pila en $F2FF en INICIO).
;
;  Se ensambla con el directorio de trabajo en src/juego/ (las rutas
;  de INCBIN de los cuerpos son relativas a esa carpeta).
; ==============================================================

    DEVICE NOSLOT64K

    ORG $8400
    INCLUDE "madmix1_body.asm"
FIN_MOTOR:

    ORG $1000
    INCLUDE "madmix_scr_body.asm"
    ASSERT $ <= $6500           ; el cuerpo de MADMIX.SCR no invade el codigo nuevo

    ORG $6500
    INCLUDE "optimizaciones.asm"
    INCLUDE "v9990.asm"         ; ORG $6C00
    INCLUDE "volcado_haz.asm"   ; a continuacion

    INCLUDE "v9990_ext.asm"     ; ORG $0100 (RAM baja)

    ; Compilacion de pruebas (tools/build.py --pruebas): GENERAR_ALEATORIO
    ; usa la semilla en vez del registro R, cuyo valor depende de cuantas
    ; instrucciones se hayan ejecutado. Asi la demo (entrada grabada) es
    ; identica tic a tic en cualquier version y se pueden comparar.
    IFDEF PRUEBAS
    ORG GENERAR_ALEATORIO + 4
    ASSERT {b $} == $ED         ; LD A,R = ED 5F
    DB $7D, $00                 ; LD A,L / NOP
    ENDIF

    SAVEBIN "../../build/ram_1000.bin", $1000, $5500
    SAVEBIN "../../build/ram_6500.bin", $6500, FIN_VOLCADO_HAZ-$6500
    SAVEBIN "../../build/ram_8400.bin", START, FIN_MOTOR-START
    SAVEBIN "../../build/ram_0100.bin", $0100, FIN_V9990_EXT-$0100

    ; El logo se ensambla al final porque comparte direcciones con el
    ; motor ($9470); su volcado ya se hizo arriba.
    ORG $9470
    INCLUDE "load_cas/logotopo_cm_body.asm"
    SAVEBIN "../../build/logotopo.bin", ENTRADA_LOGOTOPO, END_OF_FILE_LOGOTOPO-ENTRADA_LOGOTOPO
