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
TRABAJO_Y   EQU 768             ; anillo del fondo: pagina 3 entera
ACTORES_Y   EQU 512 + 96        ; actores: pagina 2, debajo de las losetas
LOSETAS_Y   EQU 512             ; losetas: pagina 2

    INCLUDE "../../build/msx2/matriz.inc"

    OUTPUT "../../build/msx2/velocidad2.rom"
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
    LD E, ($10000 + 96 * 128) >> 14
    LD HL, ($10000 + 96 * 128) & $3FFF
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
    CALL LLENAR_ANILLO
    CALL ESPERAR_CE
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
    CALL BARRA
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
    JR .OBJETIVO
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
;  COMPONER (anillo): el fondo sin actores vive en la pagina 3 como un
;  anillo de 16 x 16 losetas (la loseta (f, c) del nivel en
;  x = (c mod 16) * 16, y = 768 + (f mod 16) * 16). Por tic:
;    1. si la camara ha entrado en una columna nueva, sus 10 losetas;
;    2. la ventana del anillo a la pagina oculta (1 a 4 HMMM, segun
;       corte por los bordes del anillo);
;    3. los actores directamente en la pagina oculta (LMMM + TIMP).
; --------------------------------------------------------------
COMPONER:
    LD A, (CAMARA_X)
    AND 15
    JR NZ, .VENTANA
    ; columna nueva: c = camara_x / 16 + 12
    LD HL, (CAMARA_X)
    CALL DIV16
    ADD A, 12
    LD D, A
    LD HL, (CAMARA_Y)
    CALL DIV16
    LD E, A
    LD B, 10
.COLUMNA:
    PUSH BC
    PUSH DE
    CALL LOSETA_ANILLO
    POP DE
    POP BC
    INC E
    DJNZ .COLUMNA
.VENTANA:
    ; HMMM de la ventana: origen (cx mod 256, cy mod 256) del anillo,
    ; troceado en x por 256 y en y por 256
    LD HL, 192 * 256 + 0        ; H = ancho que falta, L = x en la ventana
    LD A, (CAMARA_X)
    LD (.SX), A
.TROZO_X:
    LD A, (.SX)
    LD C, A
    NEG                         ; 256 - sx (0 = 256)
    JR Z, .ENTERO_X
    CP H
    JR C, .ANCHO_X
.ENTERO_X:
    LD A, H
.ANCHO_X:
    LD (.NX), A
    LD A, L
    LD (.DX), A
    ; en y
    LD A, (CAMARA_Y)
    LD (.SY), A
    LD A, 144
    LD (.QUEDA_Y), A
    XOR A
    LD (.DYW), A
.TROZO_Y:
    LD A, (.SY)
    NEG
    JR Z, .ENTERO_Y
    LD B, A
    LD A, (.QUEDA_Y)
    CP B
    JR C, .ALTO_Y
    LD A, B
    JR .ALTO_Y
.ENTERO_Y:
    LD A, (.QUEDA_Y)
.ALTO_Y:
    LD (.NY), A
    PUSH HL
    ; comando
    LD A, (.SX)
    LD L, A
    LD H, 0
    LD (CMDBUF + 0), HL
    LD A, (.SY)
    LD L, A
    LD H, 3
    LD (CMDBUF + 2), HL
    LD A, (.DX)
    LD L, A
    LD H, 0
    LD DE, 32
    ADD HL, DE
    LD (CMDBUF + 4), HL
    LD A, (.DYW)
    ADD A, 24
    LD L, A
    LD A, (OCULTA)
    LD H, A
    LD (CMDBUF + 6), HL
    LD A, (.NX)
    LD L, A
    LD H, 0
    LD (CMDBUF + 8), HL
    LD A, (.NY)
    LD L, A
    LD (CMDBUF + 10), HL
    XOR A
    LD (CMDBUF + 12), A
    LD (CMDBUF + 13), A
    LD A, $D0
    LD (CMDBUF + 14), A
    LD HL, CMDBUF
    IFNDEF SIN_VENTANA
    CALL VDP_CMD
    ENDIF
    POP HL
    ; siguiente trozo en y
    LD A, (.NY)
    LD B, A
    LD A, (.SY)
    ADD A, B
    LD (.SY), A
    LD A, (.DYW)
    ADD A, B
    LD (.DYW), A
    LD A, (.QUEDA_Y)
    SUB B
    LD (.QUEDA_Y), A
    JP NZ, .TROZO_Y
    ; siguiente trozo en x
    LD A, (.NX)
    LD B, A
    LD A, L
    ADD A, B
    LD L, A
    LD A, H
    SUB B
    LD H, A
    LD A, (.SX)
    ADD A, B
    LD (.SX), A
    LD A, H
    AND A
    JP NZ, .TROZO_X

    ; actores: LMMM 24x24 con TIMP, directamente en la pagina oculta
    LD HL, 24
    LD (CMDBUF + 8), HL
    LD (CMDBUF + 10), HL
    LD A, $98
    LD (CMDBUF + 14), A
    LD IX, POS_ACTORES
    LD B, 10
    LD C, 0
.ACTORES:
    PUSH BC
    LD L, C
    LD H, 0
    LD (CMDBUF + 0), HL
    LD HL, ACTORES_Y
    LD (CMDBUF + 2), HL
    LD A, (IX + 0)
    ADD A, 32
    LD L, A
    LD H, 0
    LD (CMDBUF + 4), HL
    LD A, (IX + 1)
    ADD A, 24
    LD L, A
    LD A, (OCULTA)
    LD H, A
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
    RET

.SX EQU $C160          ; en RAM
.SY EQU $C162          ; en RAM
.NX EQU $C164          ; en RAM
.NY EQU $C166          ; en RAM
.DX EQU $C168          ; en RAM
.DYW EQU $C16A          ; en RAM
.QUEDA_Y EQU $C16C          ; en RAM

; BARRA: debajo de la ventana, en la pagina compuesta, una barra de 16 px
; por frame que ha tardado el tic (tinta) y el resto hasta 12 en negro;
; la marca blanca es el presupuesto del tic (FRAMES_TIC)
BARRA:
    LD HL, (JIFFY)
    LD DE, (INICIO_TIC)
    AND A
    SBC HL, DE
    LD A, L
    CP 12
    JR C, .CABE
    LD A, 12
.CABE:
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A                    ; ancho en px (0-192)
    LD (.ANCHO), A
    ; fondo negro de 192 x 8
    LD HL, 32
    LD (CMDBUF + 4), HL
    LD A, (OCULTA)
    LD H, A
    LD L, 180
    LD (CMDBUF + 6), HL
    LD HL, 192
    LD (CMDBUF + 8), HL
    LD HL, 8
    LD (CMDBUF + 10), HL
    XOR A
    LD (CMDBUF + 12), A
    LD (CMDBUF + 13), A
    LD A, $C0
    LD (CMDBUF + 14), A
    LD HL, CMDBUF
    CALL VDP_CMD
    LD A, (.ANCHO)
    AND A
    JR Z, .MARCA
    LD L, A
    LD H, 0
    LD (CMDBUF + 8), HL
    LD A, $11
    LD (CMDBUF + 12), A
    LD HL, CMDBUF
    CALL VDP_CMD
.MARCA:
    LD HL, 32 + FRAMES_TIC * 16 - 2
    LD (CMDBUF + 4), HL
    LD HL, 2
    LD (CMDBUF + 8), HL
    LD A, $44
    LD (CMDBUF + 12), A
    LD HL, CMDBUF
    JP VDP_CMD
.ANCHO EQU $C170

; HL / 16 -> A
DIV16:
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    LD A, L
    RET

; LOSETA_ANILLO: la loseta de la fila E, columna D (mod 32) del nivel a
; su sitio en el anillo
LOSETA_ANILLO:
    LD A, E
    CP FILAS_MATRIZ
    LD A, 0
    JR NC, .VALOR
    LD L, E
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD A, D
    AND 31
    ADD A, L
    LD L, A
    LD BC, MATRIZ
    ADD HL, BC
    LD A, (HL)
.VALOR:
    LD C, A
    AND 15
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD L, A
    LD H, 0
    LD (CMDBUF + 0), HL
    LD A, C
    AND $F0
    LD L, A
    LD H, LOSETAS_Y >> 8
    LD (CMDBUF + 2), HL
    LD A, D
    AND 15
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD L, A
    LD H, 0
    LD (CMDBUF + 4), HL
    LD A, E
    AND 15
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD L, A
    LD H, TRABAJO_Y >> 8
    LD (CMDBUF + 6), HL
    LD HL, 16
    LD (CMDBUF + 8), HL
    LD (CMDBUF + 10), HL
    XOR A
    LD (CMDBUF + 12), A
    LD (CMDBUF + 13), A
    LD A, $D0
    LD (CMDBUF + 14), A
    LD HL, CMDBUF
    JP VDP_CMD

; LLENAR_ANILLO: las 16 x 16 losetas alrededor de la camara
LLENAR_ANILLO:
    LD HL, (CAMARA_Y)
    CALL DIV16
    LD E, A
    LD B, 16
.FILA:
    PUSH BC
    LD HL, (CAMARA_X)
    CALL DIV16
    LD D, A
    LD B, 16
.COL:
    PUSH BC
    PUSH DE
    CALL LOSETA_ANILLO
    POP DE
    POP BC
    INC D
    DJNZ .COL
    POP BC
    INC E
    DJNZ .FILA
    RET

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
    DB $00, 0,  $70, 7,  $02, 0,  $43, 3,  $77, 7
    DS 22
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
