; ==============================================================
;  imagen_ram.asm -- Mad Mix Game v9990
;
;  Ensambla el juego en sus direcciones NATIVAS de RAM (las mismas
;  que deja en memoria el cargador de cinta original) y vuelca cada
;  tramo a un binario plano que luego empaqueta la ROM:
;
;    build/ram_1000.bin   $1000-$64FF  (cuerpo de MADMIX.SCR)
;    build/ram_8400.bin   $8400-$DDA0  (motor, MADMIX1.BIN)
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

    SAVEBIN "../../build/ram_1000.bin", $1000, $5500
    SAVEBIN "../../build/ram_8400.bin", START, FIN_MOTOR-START

    ; El logo se ensambla al final porque comparte direcciones con el
    ; motor ($9470); su volcado ya se hizo arriba.
    ORG $9470
    INCLUDE "load_cas/logotopo_cm_body.asm"
    SAVEBIN "../../build/logotopo.bin", ENTRADA_LOGOTOPO, END_OF_FILE_LOGOTOPO-ENTRADA_LOGOTOPO
