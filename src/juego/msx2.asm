; ==============================================================
;  msx2.asm -- Mad Mix Game MSX2 (V9938 con 128 KB de VRAM), fase 1
;
;  Sin GFX9000 pero con un MSX2 de 128 KB de VRAM, la partida se ve
;  en SCREEN 5 y el VDP compone la ventana del laberinto en cada tic
;  (fase 1: el laberinto con las losetas del MSX1, su color, el
;  scroll siguiendo a la camara y las casillas que se comen; los
;  munecos y el marcador llegan en la fase 2). Menus, portada y
;  demas pantallas siguen en SCREEN 2 como en el MSX1.
;
;  Usa los mismos enganches que el V9990 (v9990.asm): el cargador de
;  la ROM, si hay MSX2, copia ademas TABLA_M2, que trae v9990_ext.asm
;  con sus entradas cambiadas por saltos a este codigo (ver
;  imagen_ram.asm) y este codigo en $F300-$F9FF, zona que el juego no
;  usa (comprobado con un watchpoint en openMSX).
;
;  V9_PRESENTE vale 2 mientras se ve SCREEN 5 (partida) y 0 en SCREEN
;  2, asi que fuera de la partida el juego hace exactamente lo de
;  siempre. V9_HAY_EXT = 1 hace que CARGAR_NIVEL llegue aqui.
;
;  VRAM (SCREEN 5, 128 bytes por linea, 4 paginas de 256 lineas):
;    paginas 0 y 1   pantalla que se ve y la que se compone (ventana
;                    del laberinto en (32,16), como en el TMS)
;    pagina 2, y 0-127    copia de la VRAM del TMS ($0000-$3FFF): con
;                    R#14 = 4 lo que el juego escribe en el TMS cae
;                    aqui; al volver a SCREEN 2 se copia a su sitio
;    pagina 2, y 128-223  las 91 losetas del MSX1 (16 por fila; tinta
;                    color 1, papel color 2)
;    pagina 3        anillo de 16 x 16 losetas: la celda (f, c) del
;                    nivel en x = (c mod 16)*16, y = (f mod 16)*16
;  El color 2 de la paleta es el del laberinto del TMS (el fondo de
;  la tabla de color, segun REGISTRO_NIVEL_ICONO_HUD).
; ==============================================================

M2_Y_LOSETAS    EQU 640         ; pagina 2, linea 128
M2_Y_ANILLO     EQU 768         ; pagina 3
M2_VENTANA_X    EQU 32
M2_VENTANA_Y    EQU 16
M2_LOSETA_NEGRA EQU 66          ; loseta solida negra (fuera de la matriz)

    ORG $F300

; --------------------------------------------------------------
;  M2_INICIAR: lo llama el cargador (via V9_INICIAR) con las
;  interrupciones cerradas y el juego ya en RAM, en SCREEN 2. Sube
;  las losetas del MSX1 a la VRAM en 4 bpp. No abre interrupciones.
; --------------------------------------------------------------
M2_INICIAR:
    LD A, $14000 >> 14
    LD B, 14
    CALL M2_REG
    XOR A
    OUT ($99), A
    LD A, $40
    OUT ($99), A                ; escritura en $14000 (y = 640)
    XOR A
    LD (M2_T0), A
.FILA_LOSETAS:
    LD C, 0                     ; linea de la loseta * 2
.LINEA:
    LD A, (M2_T0)
    LD (M2_T), A
    LD E, 16
.LOSETA:
    LD A, (M2_T)
    CP 91
    JR NC, .VACIA
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD A, L
    OR C
    LD L, A
    PUSH DE
    LD DE, GRAFICOS_LOSETAS
    ADD HL, DE
    LD A, (HL)
    CALL M2_BYTE
    INC HL
    LD A, (HL)
    CALL M2_BYTE
    POP DE
    JR .SIGUIENTE
.VACIA:
    LD B, 8
    XOR A
.CERO:
    OUT ($98), A
    DJNZ .CERO
.SIGUIENTE:
    LD HL, M2_T
    INC (HL)
    DEC E
    JR NZ, .LOSETA
    INC C
    INC C
    LD A, C
    CP 32
    JR NZ, .LINEA
    LD A, (M2_T0)
    ADD A, 16
    LD (M2_T0), A
    CP 96
    JR NZ, .FILA_LOSETAS
    XOR A
    LD B, 14
    CALL M2_REG                 ; el juego escribe en $0000-$3FFF
    LD A, 1
    LD (V9_HAY_EXT), A
    RET

; A = 8 pixeles del MSX1 -> 4 bytes de SCREEN 5 (bit a 1: color 1,
; bit a 0: color 2)
M2_BYTE:
    LD D, A
    LD B, 4
.PAR:
    LD A, $22
    RL D
    JR NC, .IZQUIERDA
    LD A, $12
.IZQUIERDA:
    RL D
    JR NC, .DERECHA
    AND $F0
    OR $01
.DERECHA:
    OUT ($98), A
    DJNZ .PAR
    RET

; --------------------------------------------------------------
;  M2_CARGAR_NIVEL (V9_CARGAR_NIVEL_EXT): nivel nuevo. Pasa a SCREEN 5
;  si hace falta y pide la matriz entera en el primer tic.
; --------------------------------------------------------------
M2_CARGAR_NIVEL:
    PUSH HL
    PUSH DE
    PUSH BC
    ; entradas de v9990_ext.asm por encima de $0500: sin el V9990 el
    ; motor de actores del TMS puede haberlas pisado en los menus
    LD A, $C9                   ; RET
    LD (V9_PASO_ESPEJO), A
    LD (V9_TEXTO_EXT), A
    CALL M2_ENTRAR
    LD A, 2
    LD (V9_PRESENTE), A
    LD A, MODO_JUEGO
    LD (V9_MODO), A
    XOR A
    LD (M2_NEGRO), A
    INC A
    LD (M2_NUEVO), A
    POP BC
    POP DE
    POP HL
    RET

; --------------------------------------------------------------
;  M2_PONER_MODO (V9_PONER_MODO): A = modo. Solo se llega con
;  V9_PRESENTE = 2 (en partida) y desde los menus o la portada:
;  vuelta a SCREEN 2. Conserva todo menos AF y abre interrupciones.
; --------------------------------------------------------------
M2_PONER_MODO:
    CP MODO_JUEGO
    RET Z
    LD (V9_MODO), A
    PUSH HL
    PUSH DE
    PUSH BC
    CALL M2_SALIR
    POP BC
    POP DE
    POP HL
    EI
    RET

; --------------------------------------------------------------
;  M2_RELLENAR (V9_RELLENAR_EXT): fin de partida, la ventana en negro
;  y sin componer hasta el nivel siguiente o el menu.
; --------------------------------------------------------------
M2_RELLENAR:
    PUSH HL
    PUSH DE
    PUSH BC
    LD A, 1
    LD (M2_NEGRO), A
    XOR A
    LD (M2_CMD_NEGRO + 7), A
    LD HL, M2_CMD_NEGRO
    CALL M2_VDP_CMD
    LD A, 1
    LD (M2_CMD_NEGRO + 7), A
    LD HL, M2_CMD_NEGRO
    CALL M2_VDP_CMD
    POP BC
    POP DE
    POP HL
    RET

; --------------------------------------------------------------
;  M2_ENTRAR: SCREEN 2 -> SCREEN 5 (si no lo estaba ya). La VRAM del
;  TMS pasa a la copia de la pagina 2 y el juego sigue escribiendo
;  alli (R#14 = 4).
; --------------------------------------------------------------
M2_ENTRAR:
    LD A, (M2_EN_5)
    AND A
    RET NZ
    INC A
    LD (M2_EN_5), A
    CALL M2_APAGAR
    DI
    LD HL, M2_REGS_5
    CALL M2_REGS
    CALL M2_R9
    EI
    LD HL, M2_CMD_SOMBRA
    CALL M2_VDP_CMD
    LD HL, M2_CMD_BORRAR
    CALL M2_VDP_CMD
    CALL M2_ESPERAR_CE
    CALL M2_PALETA
    LD A, $FF
    LD (M2_COLOR), A
    LD A, 1
    LD (M2_OCULTA), A           ; se ve la 0, se compone la 1
    XOR A
    LD (M2_COMPUESTA), A
    JR M2_ENCENDER

; --------------------------------------------------------------
;  M2_SALIR: SCREEN 5 -> SCREEN 2, con la VRAM del TMS como la ha
;  dejado el juego.
; --------------------------------------------------------------
M2_SALIR:
    LD A, (M2_EN_5)
    AND A
    RET Z
    XOR A
    LD (M2_EN_5), A
    LD (V9_PRESENTE), A
    LD (M2_NEGRO), A
    CALL M2_APAGAR
    LD HL, M2_CMD_VOLVER
    CALL M2_VDP_CMD
    CALL M2_ESPERAR_CE
    CALL M2_PALETA              ; el color 2 vuelve a ser el del TMS
    DI
    LD HL, M2_REGS_2
    CALL M2_REGS
    CALL M2_R9
    EI
M2_ENCENDER:
    LD A, (M2_R1)
    LD (VDP_REGISTRO1_PENDIENTE), A
    RET

; Pantalla apagada mientras cambia el modo (la ISR del juego reescribe
; R#1 en cada VBLANK con VDP_REGISTRO1_PENDIENTE).
M2_APAGAR:
    LD A, (VDP_REGISTRO1_PENDIENTE)
    LD (M2_R1), A
    LD A, $A2
    LD (VDP_REGISTRO1_PENDIENTE), A
    DI
    LD B, 1
    CALL M2_REG
    EI
    RET

; R#9: 192 lineas, 50 o 60 Hz como la maquina
M2_R9:
    LD A, (TIC_FRAMES)
    CP 5
    LD A, $00
    JR NZ, .PONER
    LD A, $02
.PONER:
    LD B, 9
    ; sigue en M2_REG

; R#B = A (con interrupciones cerradas)
M2_REG:
    OUT ($99), A
    LD A, B
    OR $80
    OUT ($99), A
    RET

; HL -> pares registro, valor; termina en $FF
M2_REGS:
    LD B, (HL)
    INC HL
    BIT 7, B
    RET NZ
    LD A, (HL)
    INC HL
    CALL M2_REG
    JR M2_REGS

; Los 16 colores del TMS en el V9938 (los de la BIOS del MSX2)
M2_PALETA:
    DI
    XOR A
    LD B, 16
    CALL M2_REG
    LD HL, M2_PALETA_TMS
    LD BC, 32 * 256 + $9A
    OTIR
    EI
    RET

; --------------------------------------------------------------
;  M2_TIC (V9_TIC): en lugar del volcado al TMS, una vez por tic.
;  Ensena la pagina compuesta en el tic anterior y compone la otra:
;  las losetas visibles que han cambiado al anillo y la ventana del
;  anillo a la pagina oculta. El VDP trabaja mientras sigue el juego.
; --------------------------------------------------------------
M2_TIC:
    LD A, (M2_NEGRO)
    AND A
    RET NZ
    CALL M2_ESPERAR_CE
    LD A, (M2_COMPUESTA)
    AND A
    JR Z, .COLOR
    LD A, (M2_OCULTA)
    LD C, A
    RRCA
    RRCA
    RRCA
    OR $1F                      ; R#2: $1F pagina 0, $3F pagina 1
    DI
    OUT ($99), A
    LD A, 2 + $80
    OUT ($99), A
    EI
    LD A, C
    XOR 1
    LD (M2_OCULTA), A
.COLOR:
    ; --- color del laberinto (el fondo del TMS) en el color 2 ---
    LD A, (REGISTRO_NIVEL_ICONO_HUD)
    CALL CONSULTAR_COLOR_VDP
    AND $0F
    LD HL, M2_COLOR
    CP (HL)
    JR Z, .NUEVO
    LD (HL), A
    ADD A, A
    LD E, A
    LD D, 0
    LD HL, M2_PALETA_TMS
    ADD HL, DE
    DI
    LD A, 2
    LD B, 16
    CALL M2_REG
    LD A, (HL)
    OUT ($9A), A
    INC HL
    LD A, (HL)
    OUT ($9A), A
    EI
.NUEVO:
    ; --- nivel recien cargado: el anillo no vale ---
    LD A, (M2_NUEVO)
    AND A
    JR Z, .ESQUINA
    XOR A
    LD (M2_NUEVO), A
    LD HL, M2_ANILLO_FILA
    LD B, 0
.INVALIDAR:
    LD (HL), $FF
    INC L
    DJNZ .INVALIDAR
.ESQUINA:
    ; --- esquina de la ventana: camara * 4 px ---
    LD HL, (REGISTRO_NIVEL_POSICION_COMECOCOS)
    LD A, L
    ADD A, A
    ADD A, A
    LD (M2_SX), A               ; x mod 256 (en el anillo)
    LD A, H
    ADD A, A
    ADD A, A
    LD (M2_SY), A
    LD A, L
    RRCA
    RRCA
    AND $3F
    LD (M2_C0), A               ; columna (mod 32 al usarla)
    LD A, H
    RRCA
    RRCA
    AND $3F
    LD (M2_F), A                ; fila
    ; --- losetas visibles: 10 filas x 13 columnas ---
    LD B, 10
.FILA:
    PUSH BC
    LD A, (M2_C0)
    LD (M2_C), A
    LD B, 13
.CELDA:
    PUSH BC
    CALL M2_CELDA
    LD HL, M2_C
    LD A, (HL)
    INC A
    AND 31
    LD (HL), A
    POP BC
    DJNZ .CELDA
    LD HL, M2_F
    INC (HL)
    POP BC
    DJNZ .FILA
    ; --- la ventana del anillo a la pagina oculta ---
    CALL M2_VENTANA
    LD A, 1
    LD (M2_COMPUESTA), A
    RET

; M2_CELDA: la celda (M2_F, M2_C) al anillo si no esta ya.
M2_CELDA:
    LD A, (M2_F)
    LD D, A
    LD A, (M2_C)
    LD E, A
    LD A, D
    CP FILAS_MATRIZ
    LD A, M2_LOSETA_NEGRA
    JR NC, .VALOR
    LD L, D
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD A, L
    OR E
    LD L, A
    LD BC, MATRIZ_NIVEL
    ADD HL, BC
    LD A, (HL)
    AND $7F                     ; bit 7 = comida
.VALOR:
    LD C, A                     ; loseta
    LD A, D
    RLCA
    RLCA
    RLCA
    RLCA
    AND $F0
    LD B, A
    LD A, E
    AND $0F
    OR B
    LD L, A                     ; hueco del anillo
    LD H, HIGH M2_ANILLO_VALOR
    LD A, (HL)
    CP C
    JR NZ, .CAMBIA
    INC H                       ; M2_ANILLO_FILA
    LD A, (HL)
    CP D
    JR NZ, .CAMBIA_FILA
    INC H                       ; M2_ANILLO_COLUMNA
    LD A, (HL)
    CP E
    RET Z
    JR .CAMBIA_COLUMNA
.CAMBIA:
    LD (HL), C
    INC H
.CAMBIA_FILA:
    LD (HL), D
    INC H
.CAMBIA_COLUMNA:
    LD (HL), E
    ; HMMM: loseta C (pagina 2) -> hueco (pagina 3)
    LD A, C
    RLCA
    RLCA
    RLCA
    RLCA
    AND $F0
    LD (M2_CMD_LOSETA + 0), A   ; SX
    LD A, C
    AND $F0
    ADD A, M2_Y_LOSETAS & $FF
    LD (M2_CMD_LOSETA + 2), A   ; SY (+512)
    LD A, L
    RLCA
    RLCA
    RLCA
    RLCA
    AND $F0
    LD (M2_CMD_LOSETA + 4), A   ; DX
    LD A, L
    AND $F0
    LD (M2_CMD_LOSETA + 6), A   ; DY (+768)
    LD HL, M2_CMD_LOSETA
    JP M2_VDP_CMD

; M2_VENTANA: 192 x 144 del anillo desde (M2_SX, M2_SY) a la ventana
; de la pagina oculta, en 1-4 trozos segun corte por los bordes.
M2_VENTANA:
    LD A, (M2_OCULTA)
    LD (M2_CMD_VENTANA + 7), A  ; DY alto = pagina
    LD A, (M2_SX)
    LD C, A                     ; x en el anillo
    LD B, M2_VENTANA_X          ; x en la pantalla
    LD E, 192                   ; ancho que falta
.X:
    LD A, C
    NEG                         ; hasta el borde del anillo (0 = 256)
    JR Z, .X_ENTERO
    CP E
    JR C, .X_ANCHO
.X_ENTERO:
    LD A, E
.X_ANCHO:
    LD D, A
    LD A, C
    LD (M2_CMD_VENTANA + 0), A
    LD A, B
    LD (M2_CMD_VENTANA + 4), A
    LD A, D
    LD (M2_CMD_VENTANA + 8), A
    PUSH BC
    PUSH DE
    CALL .Y
    POP DE
    POP BC
    LD A, C
    ADD A, D
    LD C, A
    LD A, B
    ADD A, D
    LD B, A
    LD A, E
    SUB D
    LD E, A
    JR NZ, .X
    RET
.Y:
    LD A, (M2_SY)
    LD C, A
    LD B, M2_VENTANA_Y
    LD E, 144
.Y_TROZO:
    LD A, C
    NEG
    JR Z, .Y_ENTERO
    CP E
    JR C, .Y_ALTO
.Y_ENTERO:
    LD A, E
.Y_ALTO:
    LD D, A
    LD A, C
    LD (M2_CMD_VENTANA + 2), A
    LD A, B
    LD (M2_CMD_VENTANA + 6), A
    LD A, D
    LD (M2_CMD_VENTANA + 10), A
    PUSH BC
    PUSH DE
    LD HL, M2_CMD_VENTANA
    CALL M2_VDP_CMD
    POP DE
    POP BC
    LD A, C
    ADD A, D
    LD C, A
    LD A, B
    ADD A, D
    LD B, A
    LD A, E
    SUB D
    LD E, A
    JR NZ, .Y_TROZO
    RET

; --------------------------------------------------------------
;  M2_VDP_CMD: HL -> 15 bytes para R#32-R#46. Espera a que acabe el
;  comando anterior.
; --------------------------------------------------------------
M2_VDP_CMD:
    CALL M2_ESPERAR_CE
    DI
    LD A, 32
    OUT ($99), A
    LD A, 17 + $80
    OUT ($99), A
    LD BC, 15 * 256 + $9B
    OTIR
    EI
    RET

; Espera a que el VDP acabe el comando (S#2 bit 0); la ISR del juego
; lee S#0, asi que R#15 vuelve a 0 antes de abrir interrupciones.
M2_ESPERAR_CE:
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
    JR NZ, M2_ESPERAR_CE
    RET

; --------------------------------------------------------------
;  Datos
; --------------------------------------------------------------
M2_REGS_5:                      ; SCREEN 5, sin sprites, pagina 0
    DB 0, $06, 2, $1F, 8, $0A, 14, $10000 >> 14, 15, 0, 18, 0, 23, 0
    DB 10, 0, 11, 0
    DB $FF
M2_REGS_2:                      ; SCREEN 2 como la deja la BIOS
    DB 14, 0, 0, $02, 2, $06, 3, $FF, 4, $03, 5, $36, 6, $07
    DB 8, $08, 10, 0, 11, 0, 23, 0
    DB $FF

; Paleta de la BIOS del MSX2 (0RRR0BBB, 00000GGG)
M2_PALETA_TMS:
    DB $00, 0,  $00, 0,  $11, 6,  $33, 7,  $17, 1,  $27, 3,  $51, 1,  $27, 6
    DB $71, 1,  $73, 3,  $61, 6,  $64, 6,  $11, 4,  $65, 2,  $55, 5,  $77, 7

; Comandos (R#32-R#46: SX, SY, DX, DY, NX, NY, CLR, ARG, CMD)
M2_CMD_SOMBRA:                  ; HMMM: VRAM del TMS -> copia en la pagina 2
    DW 0, 0, 0, 512, 256, 128
    DB 0, 0, $D0
M2_CMD_VOLVER:                  ; HMMM: copia -> VRAM del TMS
    DW 0, 512, 0, 0, 256, 128
    DB 0, 0, $D0
M2_CMD_BORRAR:                  ; HMMV: paginas 0 y 1 en negro
    DW 0, 0, 0, 0, 256, 512
    DB 0, 0, $C0
M2_CMD_NEGRO:                   ; HMMV: la ventana en negro (DY alto = pagina)
    DW 0, 0, M2_VENTANA_X, M2_VENTANA_Y, 192, 144
    DB 0, 0, $C0
M2_CMD_LOSETA:                  ; HMMM: loseta -> anillo (se rellenan los bytes bajos)
    DW 0, M2_Y_LOSETAS & $FF00, 0, M2_Y_ANILLO, 16, 16
    DB 0, 0, $D0
M2_CMD_VENTANA:                 ; HMMM: anillo -> ventana
    DW 0, M2_Y_ANILLO, 0, 0, 0, 0
    DB 0, 0, $D0

; Variables
M2_EN_5:      DB 0              ; 1: SCREEN 5
M2_NEGRO:     DB 0              ; 1: fin de partida, no se compone
M2_NUEVO:     DB 0              ; 1: nivel recien cargado
M2_OCULTA:    DB 1              ; pagina que se compone
M2_COMPUESTA: DB 0              ; 1: la pagina oculta ya esta compuesta
M2_COLOR:     DB $FF            ; color del TMS que hay en el color 2
M2_R1:        DB $E2
M2_SX:        DB 0
M2_SY:        DB 0
M2_C0:        DB 0
M2_C:         DB 0
M2_F:         DB 0
M2_T0:        DB 0
M2_T:         DB 0

FIN_MSX2:
    ASSERT FIN_MSX2 <= $F900

; Anillo (no se cargan): loseta, fila y columna de la celda que hay en
; cada hueco
M2_ANILLO_VALOR   EQU $F900
M2_ANILLO_FILA    EQU $FA00
M2_ANILLO_COLUMNA EQU $FB00
