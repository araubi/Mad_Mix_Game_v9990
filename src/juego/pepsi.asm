; ==============================================================
;  pepsi.asm -- Mad Mix Game v9990: opcion "3 MAD MIX GAME / 3 THE
;  PEPSI CHALLENGE" del menu principal (peticion de Ruben, 2026-10-22).
;
;  The Pepsi Challenge (Topo Soft / US Gold, 1988) es la version inglesa
;  de Mad Mix Game: la mascota de Pepsi en lugar del comecocos y sin el
;  nivel 1 (empieza en el 2, que cuenta como 1, y acaba en el 15, el 14).
;  Sus sprites estan en data/pepsi/sprites_pepsi.bin (sacados de la
;  cinta); tools/graficos.py genera:
;    build/pepsi_delta.bin  XOR entre los sprites de Mad Mix y los de
;                           Pepsi, en tramos (para el TMS)
;    build/v9_pepsi.inc     las partes de la mascota para el V9990
;
;  Memoria:
;    $0F00-$0FFF  codigo y textos (con y sin GFX9000; la zona de
;                 mascaras de los actores, desde $0500, no llega aqui)
;    $7700-$7FEF  PEPSI_DELTA: solo sin GFX9000 (con GFX9000 ahi van los
;                 buferes del espejo y SOMBRA_MATRIZ)
;    $7FF0-$83AF  V9_META_ELEGIR y V9_META_PEPSI: solo con GFX9000 (sin
;                 GFX9000 ahi va TRASPUESTA, del volcado al TMS)
;    $83B0-$83FF  textos de la opcion 3
; ==============================================================

    ORG $0F00

MODO_PEPSI:        DB 0         ; 0 Mad Mix Game, 1 The Pepsi Challenge
PEPSI_TEXTO_JUEGO: DW TEXTO_OPCION_MAD_MIX

; En lugar de DIBUJAR_MENU_PRINCIPAL: el menu con la opcion nueva, dos
; columnas mas a la izquierda para que quepa "3 THE PEPSI CHALLENGE"
PEPSI_DIBUJAR_MENU:
    LD HL, $0530
    LD DE, TEXTO_OPCION_TECLADO
    CALL DIBUJAR_TEXTO_VRAM
    LD HL, $0730
    LD DE, TEXTO_OPCION_JOYSTICK
    CALL DIBUJAR_TEXTO_VRAM
    LD HL, $0930
    LD DE, (PEPSI_TEXTO_JUEGO)
    CALL DIBUJAR_TEXTO_VRAM
    LD HL, $0B30
    LD DE, TEXTO_OPCION_REDEFINIR_TECLAS
    CALL DIBUJAR_TEXTO_VRAM
    LD HL, $0D30
    LD DE, TEXTO_OPCION_DEMO
    CALL DIBUJAR_TEXTO_VRAM
    LD HL, $1030
    LD DE, TEXTO_OPCION_JUGAR
    JP DIBUJAR_TEXTO_VRAM

; En lugar de las 2 primeras instrucciones de DESPACHAR_ACCION_MENU
; (BIT 5,A / JP NZ,SELECCIONAR_OPCION_DEMO): la tecla 3 (bit 2)
PEPSI_DESPACHAR:
    BIT 5, A
    JP NZ, SELECCIONAR_OPCION_DEMO
    BIT 2, A
    JP Z, DESPACHAR_ACCION_MENU + 5
    CALL PEPSI_ALTERNAR
    CALL PEPSI_DIBUJAR_MENU
    JP ESPERAR_TECLA_SOLTADA    ; una pulsacion, un cambio

; Cambia de juego: nivel inicial, numero de fase, texto del menu y la
; mascota (en el V9990 la elige V9_META_ELEGIR; en el TMS se aplica el
; XOR a los sprites)
PEPSI_ALTERNAR:
    LD A, (MODO_PEPSI)
    XOR 1
    LD (MODO_PEPSI), A
    LD B, A
    INC A
    LD (NIVEL_INICIAL + 1), A   ; LD A,1 / LD A,2
    LD (NIVEL_VUELTA + 1), A    ; LD (HL),1 / LD (HL),2
    LD HL, TABLA_NUMEROS_NIVEL
    LD DE, TEXTO_OPCION_MAD_MIX
    DEC B
    JR NZ, .TABLAS
    DEC HL                      ; el nivel 2 se ve como el 1
    DEC HL
    LD DE, TEXTO_OPCION_PEPSI
.TABLAS:
    LD (NUMEROS_NIVEL_BASE + 1), HL
    LD (PEPSI_TEXTO_JUEGO), DE
    LD A, (V9_PRESENTE)
    AND A
    RET NZ
    ; TMS: el motor da la vuelta a los sprites en su sitio (bits 6-7 del
    ; indicador de PTR_TABLA_SPRITES); se dejan derechos antes del XOR
    LD A, 3
    LD ($8435), A
    LD A, $18
    LD ($8436), A
    LD C, 0
.SPRITE:
    LD A, C
    CP 12
    JR C, .DERECHO
    CP 57
    JR C, .SIGUIENTE
    CP 62
    JR NC, .XOR
.DERECHO:
    LD L, C
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    LD DE, PTR_TABLA_SPRITES
    ADD HL, DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    INC HL
    LD ($8433), DE
    LD A, (HL)
    LD B, A
    AND $3F
    LD (HL), A
    BIT 7, B
    CALL NZ, INVERTIR_BITS_PATRON_ACTOR
    BIT 6, B
    CALL NZ, INVERTIR_ORDEN_BYTES_PATRON_ACTOR
.SIGUIENTE:
    INC C
    JR .SPRITE
.XOR:
    LD HL, PEPSI_DELTA
    LD DE, SPR00_PM_VULN_DER_CERRADA
.TRAMO:
    LD C, (HL)                  ; bytes iguales
    INC HL
    LD B, (HL)                  ; bytes distintos
    INC HL
    LD A, C
    OR B
    JR Z, .INDICADORES
    LD A, C
    ADD A, E
    LD E, A
    ADC A, D
    SUB E
    LD D, A
    LD A, B
    AND A
    JR Z, .TRAMO
.BYTE:
    LD A, (DE)
    XOR (HL)
    LD (DE), A
    INC HL
    INC DE
    DJNZ .BYTE
    JR .TRAMO
.INDICADORES:
    ; hueco de la derecha de las vistas de lado (0-2 y 7-9): 6 <-> 2
    LD HL, PTR_TABLA_SPRITES + 2
    CALL .TRES
    LD HL, PTR_TABLA_SPRITES + 7 * 4 + 2
.TRES:
    LD B, 3
.INDICADOR:
    LD A, (HL)
    XOR 4
    LD (HL), A
    INC HL
    INC HL
    INC HL
    INC HL
    DJNZ .INDICADOR
    RET

FIN_PEPSI:
    ASSERT FIN_PEPSI <= $1000

; Textos de la opcion 3, detras de TRASPUESTA (libre con y sin GFX9000)
    ORG SOMBRA_MATRIZ + 928 + 960
TEXTO_OPCION_MAD_MIX:
    DB 21, $71, "3 MAD MIX GAME       "
TEXTO_OPCION_PEPSI:
    DB 21, $51, "3 THE PEPSI CHALLENGE"
FIN_TEXTOS_PEPSI:
    ASSERT FIN_TEXTOS_PEPSI <= $8400

; --------------------------------------------------------------
    ORG $7700
PEPSI_DELTA:
    INCBIN "../../build/pepsi_delta.bin"
FIN_PEPSI_DELTA:
    ASSERT FIN_PEPSI_DELTA <= SOMBRA_MATRIZ + 928

; --------------------------------------------------------------
;  V9_META_ELEGIR: desde V9_TIC_SPRITES, A = sprite*2 + espejo.
;  Devuelve HL -> puntero a las partes del actor (V9_META o, con The
;  Pepsi Challenge, V9_META_PEPSI para los sprites 0-11 y 57-61).
; --------------------------------------------------------------
    ORG SOMBRA_MATRIZ + 928
V9_META_ELEGIR:
    LD L, A
    LD H, 0
    LD DE, V9_META
    LD A, (MODO_PEPSI)
    AND A
    JR Z, .INDICE
    LD A, L
    CP 24
    JR C, .PEPSI                ; sprites 0-11
    SUB 57 * 2
    CP 10
    JR NC, .INDICE              ; ni 0-11 ni 57-61
    ADD A, 24
.PEPSI:
    LD L, A
    LD DE, V9_META_PEPSI
.INDICE:
    ADD HL, HL
    ADD HL, DE
    RET

    INCLUDE "../../build/v9_pepsi.inc"
FIN_V9_PEPSI:
    ASSERT FIN_V9_PEPSI <= TEXTO_OPCION_MAD_MIX
