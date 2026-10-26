; ==============================================================
;  volumen.asm -- Mad Mix Game v9990: ROM de prueba con volumen en los
;  munecos (tools/build.py --volumen, -DVOLUMEN).
;
;  Los sprites que no son fantasmas se dibujan sombreados (luz desde
;  arriba a la izquierda, tools/graficos.py: sombrear) con una paleta
;  propia en las entradas 0-15. En partida esas entradas no las usa el
;  TMS (la capa A va con la del marco, 48-63); al volver a los menus se
;  repone la del TMS.
;
;  Va en la RAM baja, $0040-$00FF, libre en el juego (el $0038 es el
;  salto a la interrupcion).
; ==============================================================

    ORG $0040

; V9_PONER_MODO, partida: en lugar de cargar solo la paleta del marco
V9_VOL_JUEGO:
    CALL V9_CARGAR_PALETA
    XOR A
    LD C, 16
    LD HL, V9_PALETA_VOLUMEN
    JP V9_CARGAR_PALETA

; V9_PONER_MODO, espejo: la paleta del TMS otra vez en 0-15 (B = 13,
; A = $04 para V9_ESCRIBIR_REG, como estaban)
V9_VOL_ESPEJO:
    PUSH AF
    XOR A
    LD C, 16
    LD HL, V9_PALETA_TMS
    CALL V9_CARGAR_PALETA
    POP AF
    LD B, 13
    JP V9_ESCRIBIR_REG

; V9_META_ELEGIR (.NO_FANTASMA), L = sprite * 2 + espejo: los sombreados
; usan la paleta 0-15; los fantasmas (27-36) y la mascota de Pepsi (0-11,
; 57-61 y 63 en The Pepsi Challenge) siguen con la 32-47
V9_VOL_ELEGIR:
    LD A, L
    SUB 27 * 2
    CP 10 * 2
    JR C, .FIN
    LD A, (MODO_PEPSI)
    AND A
    JR Z, .SOMBREADO
    LD A, L
    CP 12 * 2
    JR C, .FIN
    SUB 57 * 2
    CP 5 * 2
    JR C, .FIN
    AND $FE
    CP 6 * 2
    JR Z, .FIN
.SOMBREADO:
    LD A, $20
    LD (V9_PREPARAR_SPRITES.ATRIB + 1), A
.FIN:
    JP V9_PAC_AMARILLO

    INCLUDE "../../build/v9_volumen.inc"
FIN_VOLUMEN:
    ASSERT FIN_VOLUMEN <= $0100
