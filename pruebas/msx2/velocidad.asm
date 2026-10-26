; ==============================================================
;  velocidad.asm -- Mad Mix Game MSX2, fase 0: prueba de velocidad del
;  V9938 en SCREEN 5 (ROM de 32 KB, necesita 128 KB de VRAM).
;
;  En cada tic compone la ventana del juego (192 x 144) con los comandos
;  del VDP, como lo haria la version MSX2:
;    1. 13 x 10 losetas de 16 x 16 (HMMM) en una zona de trabajo de la
;       pagina 3, desde las losetas originales del MSX1 en la pagina 2;
;    2. 10 actores de 24 x 24 con transparencia (LMMM + TIMP) encima;
;    3. la ventana entera (HMMM 192 x 144) a la pagina oculta, desplazada
;       por la parte de loseta del scroll, y cambia de pagina.
;  La camara avanza 4 px por tic, como el comecocos.
;
;  Resultado en RAM: TICS (tics hechos) e HISTOGRAMA (16 contadores de
;  16 bits: tics que tardaron 0, 1, ... 15 frames en componerse).
;  Datos: pruebas/msx2/datos.py (build/msx2/).
; ==============================================================

JIFFY       EQU $FC9E
RSLREG      EQU $0138
ENASLT      EQU $0024
EXPTBL      EQU $FCC1

TICS        EQU $C100
HISTOGRAMA  EQU $C102           ; 16 x 2 bytes
CAMARA_X    EQU $C130
CAMARA_Y    EQU $C132
OBJETIVO    EQU $C134
INICIO_TIC  EQU $C136
OCULTA      EQU $C138           ; pagina que se compone (0 o 1)
CMDBUF      EQU $C140           ; R#32-R#46

    IFDEF HZ60
FRAMES_TIC  EQU 6
R9          EQU $80             ; 212 lineas, 60 Hz
    ELSE
FRAMES_TIC  EQU 5
R9          EQU $82             ; 212 lineas, 50 Hz
    ENDIF
TRABAJO_Y   EQU 768             ; zona de trabajo: pagina 3, lineas 0-159
ACTORES_Y   EQU 768 + 160       ; actores: pagina 3, desde la linea 160
LOSETAS_Y   EQU 512             ; losetas: pagina 2

    INCLUDE "../../build/msx2/matriz.inc"

    OUTPUT "../../build/msx2/velocidad.rom"
    ORG $4000
    DB "AB"
    DW INICIO
    DS 12

INICIO:
    DI
    ; pagina 2 al mismo slot que la 1 (el cartucho)
    CALL RSLREG
    RRCA
    RRCA
    AND 3
    LD C, A
    LD B, 0
    LD HL, EXPTBL
    ADD HL, BC
    LD A, (HL)
    AND $80
    OR C
    LD C, A
    INC HL
    INC HL
    INC HL
    INC HL
    LD A, (HL)
    AND $0C
    OR C
    LD H, $80
    CALL ENASLT
    DI
    ; SCREEN 5, 212 lineas, 50 Hz, sprites apagados
    LD HL, REGISTROS
.REG:
    LD A, (HL)
    INC HL
    CP $FF
    JR Z, .PALETA
    LD B, A
    LD A, (HL)
    INC HL
    OUT ($99), A
    LD A, B
    OR $80
    OUT ($99), A
    JR .REG
.PALETA:
    XOR A
    OUT ($99), A
    LD A, 16 + $80
    OUT ($99), A
    LD HL, PALETA
    LD BC, 32 * 256 + $9A
    OTIR
    ; toda la VRAM a 0, y el marco (color 3) en las paginas 0 y 1
    LD HL, CMD_BORRAR
    CALL VDP_CMD
    LD HL, CMD_MARCO
    CALL VDP_CMD
    CALL ESPERAR_CE
    ; losetas a la pagina 2 y actores a la pagina 3
    LD E, $10000 >> 14
    LD HL, $10000 & $3FFF
    CALL VRAM_ESCRITURA
    LD HL, LOSETAS
    LD DE, FIN_LOSETAS - LOSETAS
    CALL SUBIR
    LD E, ($18000 + 160 * 128) >> 14
    LD HL, ($18000 + 160 * 128) & $3FFF
    CALL VRAM_ESCRITURA
    LD HL, ACTORES
    LD DE, FIN_ACTORES - ACTORES
    CALL SUBIR
    ; estado
    LD HL, TICS
    LD B, $40
.CERO:
    LD (HL), 0
    INC HL
    DJNZ .CERO
    LD HL, 0
    LD (CAMARA_X), HL
    LD HL, 32
    LD (CAMARA_Y), HL
    LD A, 1
    LD (OCULTA), A
    EI
    HALT
    LD HL, (JIFFY)
    LD (OBJETIVO), HL

BUCLE:
    ; espera al frame del tic
    LD HL, (JIFFY)
    LD DE, (OBJETIVO)
    AND A
    SBC HL, DE
    JP M, BUCLE
    LD HL, (JIFFY)
    LD (INICIO_TIC), HL
    CALL COMPONER
    CALL ESPERAR_CE
    ; frames que ha tardado
    LD HL, (JIFFY)
    LD DE, (INICIO_TIC)
    AND A
    SBC HL, DE
    LD A, L
    CP 15
    JR C, .CONTAR
    LD A, 15
.CONTAR:
    ADD A, A
    LD E, A
    LD D, 0
    LD HL, HISTOGRAMA
    ADD HL, DE
    INC (HL)
    JR NZ, .TIC
    INC HL
    INC (HL)
.TIC:
    LD HL, (TICS)
    INC HL
    LD (TICS), HL
    ; ensenar la pagina compuesta (R#2: $1F pagina 0, $3F pagina 1)
    LD A, (OCULTA)
    RRCA
    RRCA
    RRCA
    OR $1F
    DI
    OUT ($99), A
    LD A, 2 + $80
    OUT ($99), A
    EI
    LD A, (OCULTA)
    XOR 1
    LD (OCULTA), A
    ; camara: 4 px a la derecha por tic; cada 128 tics, 4 px abajo
    LD HL, (CAMARA_X)
    LD DE, 4
    ADD HL, DE
    LD A, H
    AND 1
    LD H, A
    LD (CAMARA_X), HL
    LD A, L
    OR H
    JR NZ, .OBJETIVO
    LD HL, (CAMARA_Y)
    ADD HL, DE
    PUSH HL
    LD DE, (FILAS_MATRIZ - 10) * 16
    AND A
    SBC HL, DE
    POP HL
    JR C, .Y
    LD HL, 0
.Y:
    LD (CAMARA_Y), HL
.OBJETIVO:
    ; siguiente tic: FRAMES_TIC despues; si va tarde, desde ahora
    LD HL, (OBJETIVO)
    LD DE, FRAMES_TIC
    ADD HL, DE
    LD (OBJETIVO), HL
    EX DE, HL
    LD HL, (JIFFY)
    AND A
    SBC HL, DE
    JP M, BUCLE
    LD HL, (JIFFY)
    LD (OBJETIVO), HL
    JP BUCLE

; --------------------------------------------------------------
;  COMPONER: la ventana en la pagina OCULTA
; --------------------------------------------------------------
COMPONER:
    ; losetas: HMMM 16x16, NX/NY fijos
    LD HL, 16
    LD (CMDBUF + 8), HL
    LD (CMDBUF + 10), HL
    XOR A
    LD (CMDBUF + 12), A
    LD (CMDBUF + 13), A
    LD A, $D0
    LD (CMDBUF + 14), A
    ; fila y columna de la primera loseta
    LD HL, (CAMARA_Y)
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    LD A, L
    LD (.FILA), A
    LD HL, (CAMARA_X)
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    LD A, L
    LD (.COLUMNA), A
    LD HL, TRABAJO_Y
    LD (CMDBUF + 6), HL         ; DY
    LD C, 10
.FILAS:
    ; puntero a la fila en la matriz
    LD A, (.FILA)
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD DE, MATRIZ
    ADD HL, DE
    LD (.PUNTERO), HL
    LD HL, 0
    LD (CMDBUF + 4), HL         ; DX
    LD A, (.COLUMNA)
    LD B, 13
.COLUMNAS:
    PUSH BC
    PUSH AF
    AND 31
    LD HL, (.PUNTERO)
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO
    INC H
.SIN_ACARREO:
    LD A, (HL)                  ; valor de la casilla = loseta original
    LD C, A
    AND 15
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD (CMDBUF + 0), A          ; SX = (v mod 16) * 16
    XOR A
    LD (CMDBUF + 1), A
    LD A, C
    AND $F0
    LD (CMDBUF + 2), A          ; SY = 512 + (v div 16) * 16
    LD A, LOSETAS_Y >> 8
    LD (CMDBUF + 3), A
    LD HL, CMDBUF
    IFNDEF SIN_LOSETAS
    CALL VDP_CMD
    ENDIF
    LD HL, (CMDBUF + 4)
    LD DE, 16
    ADD HL, DE
    LD (CMDBUF + 4), HL
    POP AF
    INC A
    POP BC
    DJNZ .COLUMNAS
    LD HL, (CMDBUF + 6)
    LD DE, 16
    ADD HL, DE
    LD (CMDBUF + 6), HL
    LD A, (.FILA)
    INC A
    LD (.FILA), A
    DEC C
    JR NZ, .FILAS

    ; actores: LMMM 24x24 con TIMP
    LD HL, 24
    LD (CMDBUF + 8), HL
    LD (CMDBUF + 10), HL
    LD A, $98
    LD (CMDBUF + 14), A
    LD IX, POS_ACTORES
    LD B, 10
    LD C, 0                     ; x en la hoja de actores
.ACTORES:
    PUSH BC
    LD L, C
    LD H, 0
    LD (CMDBUF + 0), HL
    LD HL, ACTORES_Y
    LD (CMDBUF + 2), HL
    LD L, (IX + 0)
    LD H, 0
    LD (CMDBUF + 4), HL
    LD L, (IX + 1)
    LD H, TRABAJO_Y >> 8
    LD (CMDBUF + 6), HL
    LD HL, CMDBUF
    IFNDEF SIN_ACTORES
    CALL VDP_CMD
    ENDIF
    INC IX
    INC IX
    POP BC
    LD A, C
    ADD A, 24
    LD C, A
    DJNZ .ACTORES

    ; ventana: HMMM 192 x 144 a la pagina oculta
    LD A, (CAMARA_X)
    AND 15
    LD L, A
    LD H, 0
    LD (CMDBUF + 0), HL
    LD A, (CAMARA_Y)
    AND 15
    LD L, A
    LD H, TRABAJO_Y >> 8
    LD (CMDBUF + 2), HL
    LD HL, 32
    LD (CMDBUF + 4), HL
    LD A, (OCULTA)
    LD H, A
    LD L, 24
    LD (CMDBUF + 6), HL
    LD HL, 192
    LD (CMDBUF + 8), HL
    LD HL, 144
    LD (CMDBUF + 10), HL
    LD A, $D0
    LD (CMDBUF + 14), A
    LD HL, CMDBUF
    IFNDEF SIN_VENTANA
    JP VDP_CMD
    ELSE
    RET
    ENDIF

.FILA EQU $C160          ; en RAM
.COLUMNA EQU $C162          ; en RAM
.PUNTERO EQU $C164          ; en RAM

; posiciones de los 10 actores en la zona de trabajo (x, y)
POS_ACTORES:
    DB 20, 20,  60, 30,  100, 20,  140, 40,  170, 24
    DB 30, 80,  70, 100,  110, 90,  150, 110,  180, 70

; --------------------------------------------------------------
;  VDP_CMD: HL -> 15 bytes para R#32-R#46. Espera a que acabe el
;  anterior.
; --------------------------------------------------------------
VDP_CMD:
    CALL ESPERAR_CE
    DI
    LD A, 32
    OUT ($99), A
    LD A, 17 + $80
    OUT ($99), A
    LD BC, 15 * 256 + $9B
    OTIR
    EI
    RET

; Espera a que el VDP acabe el comando (S#2 bit 0), con las
; interrupciones abiertas entre lectura y lectura.
ESPERAR_CE:
    DI
    LD A, 2
    OUT ($99), A
    LD A, 15 + $80
    OUT ($99), A
    IN A, ($99)
    LD B, A
    XOR A
    OUT ($99), A
    LD A, 15 + $80
    OUT ($99), A
    EI
    BIT 0, B
    JR NZ, ESPERAR_CE
    RET

; E = bits 14-16 de la direccion, HL = bits 0-13
VRAM_ESCRITURA:
    LD A, E
    OUT ($99), A
    LD A, 14 + $80
    OUT ($99), A
    LD A, L
    OUT ($99), A
    LD A, H
    AND $3F
    OR $40
    OUT ($99), A
    RET

; HL -> datos, DE = bytes
SUBIR:
    LD C, $98
.BUCLE:
    OUTI
    DEC DE
    LD A, D
    OR E
    JR NZ, .BUCLE
    RET

REGISTROS:
    DB 0, $06, 1, $60, 2, $1F, 5, $EF, 11, $00, 6, $0F, 7, $03
    DB 8, $0A, 9, R9, 14, 0, 15, 0, 18, 0, 23, 0, $FF
; colores: 0 negro, 1 tinta (amarillo), 2 fondo (azul oscuro), 3 marco
PALETA:
    DB $00, 0,  $70, 7,  $02, 0,  $43, 3
    DS 24
CMD_BORRAR:                     ; HMMV de toda la VRAM (1024 lineas)
    DW 0, 0, 0, 0, 256, 1023
    DB 0, 0, $C0
CMD_MARCO:                      ; HMMV de las paginas 0 y 1 con el color 3
    DW 0, 0, 0, 0, 256, 512
    DB $33, 0, $C0

MATRIZ:
    INCBIN "../../build/msx2/matriz.bin"
LOSETAS:
    INCBIN "../../build/msx2/losetas.bin"
FIN_LOSETAS:
ACTORES:
    INCBIN "../../build/msx2/actores.bin", 0, 24 * 128
FIN_ACTORES:
    ASSERT $ <= $C000
    DS $C000 - $, $FF
    OUTEND
