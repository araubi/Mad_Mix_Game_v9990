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
;    build/pepsi_subtablas.bin, pepsi_indicadores.bin
;                           los otros XOR: animacion de The Pepsi
;                           Challenge (sube andando; sprites 64/65 ->
;                           63 y 63 reflejado) y huecos/puntero del 63
;    build/v9_pepsi.inc     las partes de la mascota para el V9990 (y el
;                           comecocos rojo hacia arriba)
;
;  Memoria:
;    $0F00-$0FFF  codigo y textos (con y sin GFX9000; la zona de
;                 mascaras de los actores, desde $0500, no llega aqui)
;    $7700-$7FEF  PEPSI_DELTA y PEPSI_SPR63 ($7F60): solo sin GFX9000 (con
;                 GFX9000 ahi van los buferes del espejo y SOMBRA_MATRIZ)
;    $7FF0-$83AF  V9_META_ELEGIR y V9_META_PEPSI: solo con GFX9000 (sin
;                 GFX9000 ahi va TRASPUESTA, del volcado al TMS)
;    $83B0-$83FF  textos de la opcion 3
;    $DDA1-$DE03  PEPSI_SUBTABLAS y PEPSI_INDICADORES (libre tras el motor)
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

; Cambia de juego: nivel inicial, numero de fase, texto del menu, la
; animacion de la mascota (subtablas de direccion) y sus sprites (en el
; V9990 los elige V9_META_ELEGIR; en el TMS se aplican los XOR)
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
    LD HL, PEPSI_SUBTABLAS
    LD DE, SUBTABLA_DIRECCION_A + 16
    CALL PEPSI_XOR
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
    JR Z, .SIGUIENTE
    CP 64
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
    ; indicadores (hueco de las vistas de lado) y puntero del 63
    LD HL, PEPSI_INDICADORES
    LD DE, PTR_TABLA_SPRITES + 2
    CALL PEPSI_XOR
    LD HL, PEPSI_DELTA
    LD DE, SPR00_PM_VULN_DER_CERRADA
; XOR en tramos (bytes iguales, bytes distintos, los distintos) desde DE
; hasta un tramo (0, 0)
PEPSI_XOR:
    LD C, (HL)                  ; bytes iguales
    INC HL
    LD B, (HL)                  ; bytes distintos
    INC HL
    LD A, C
    OR B
    RET Z
    LD A, C
    ADD A, E
    LD E, A
    ADC A, D
    SUB E
    LD D, A
    LD A, B
    AND A
    JR Z, PEPSI_XOR
.BYTE:
    LD A, (DE)
    XOR (HL)
    LD (DE), A
    INC HL
    INC DE
    DJNZ .BYTE
    JR PEPSI_XOR

; Con el V9990, los fantasmas vulnerables hacia arriba usan el 31 y el 32
; reflejados (blancos en V9_META) en lugar de los mismos que los normales
; (azules); en el TMS siguen igual. Desde V9_INICIAR.
V9_FANTASMAS_BLANCOS:
    LD HL, $9F9F
    LD (TABLA_ANIMACION_PELMAZOIDE + 38), HL
    LD HL, $A0A0
    LD (TABLA_ANIMACION_PELMAZOIDE + 40), HL
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
    ASSERT FIN_PEPSI_DELTA <= PEPSI_SPR63
; el sprite 63 de The Pepsi Challenge (su 64: la mascota hacia arriba);
; en el TMS, PTR_TABLA_SPRITES apunta aqui (PEPSI_INDICADORES)
    ORG SOMBRA_MATRIZ + 928 - 144
PEPSI_SPR63:
    ASSERT PEPSI_SPR63 = $7F60  ; tools/graficos.py
    INCBIN "data/pepsi/sprites_pepsi.bin", 17 * 144, 144
FIN_PEPSI_SPR63:

; --------------------------------------------------------------
;  Tras el motor ($DDA1-$DE03, libre): los otros dos XOR
; --------------------------------------------------------------
    ORG FIN_MOTOR
PEPSI_SUBTABLAS:                ; desde SUBTABLA_DIRECCION_A + 16
    INCBIN "../../build/pepsi_subtablas.bin"
PEPSI_INDICADORES:              ; desde PTR_TABLA_SPRITES + 2
    INCBIN "../../build/pepsi_indicadores.bin"
FIN_PEPSI_TABLAS:
    ASSERT FIN_PEPSI_TABLAS <= BUFFER_LOSETAS_TRABAJO

; --------------------------------------------------------------
;  V9_META_ELEGIR: desde V9_PREPARAR_SPRITES, A = sprite*2 + espejo.
;  Devuelve HL -> puntero a las partes del actor: V9_META o, con The
;  Pepsi Challenge, V9_META_PEPSI para los sprites 0-11, 57-61 y 63. Con
;  Mad Mix, el 6 (hacia arriba) con la bola de poder (MODO_ESPECIAL 1,
;  el que elige la subtabla de direccion B) es el rojo.
; --------------------------------------------------------------
    ORG SOMBRA_MATRIZ + 928
V9_META_ELEGIR:
    LD L, A
    LD H, 0
    LD DE, V9_META
    LD A, (MODO_PEPSI)
    AND A
    JR NZ, .PEPSI_MODO
    LD A, L
    AND $FE
    CP 6 * 2
    JR NZ, .INDICE
    LD A, (MODO_ESPECIAL)
    AND $07
    DEC A
    JR NZ, .INDICE
    LD HL, .ROJO
    RET
.ROJO:
    DW V9_META_ROJO_ARRIBA
.PEPSI_MODO:
    LD A, L
    CP 24
    JR C, .PEPSI                ; sprites 0-11
    SUB 57 * 2
    CP 10
    JR C, .MAS24                ; 57-61
    SUB 12
    CP 2
    JR NC, .INDICE              ; ni 0-11, ni 57-61, ni 63
    ADD A, 10                   ; 63 -> 34, 35
.MAS24:
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
