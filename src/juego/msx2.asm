; ==============================================================
;  msx2.asm -- Mad Mix Game MSX2 (V9938 con 128 KB de VRAM), fase 2
;
;  Sin GFX9000 pero con un MSX2 de 128 KB de VRAM, la partida se ve
;  en SCREEN 5 y el VDP compone la ventana del laberinto en cada tic:
;  el laberinto con las losetas del MSX1, su color, el scroll
;  siguiendo a la camara y las casillas que se comen (fase 1); los
;  munecos con transparencia (LMMM desde una cache en la VRAM), el
;  recuadro de color del comecocos, el marco, las vidas, los puntos y
;  los textos FASE, READY? y ESTAS FRITO (fase 2). Menus, portada y
;  demas pantallas siguen en SCREEN 2 como en el MSX1.
;
;  Usa los mismos enganches que el V9990 (v9990.asm): el cargador de
;  la ROM, si hay MSX2, copia ademas TABLA_M2, que trae v9990_ext.asm
;  con sus entradas cambiadas por saltos a este codigo (ver
;  imagen_ram.asm) y este codigo en $F300-$FBFF, zona que el juego no
;  usa (comprobado con un watchpoint en openMSX). Las tablas grandes
;  van en $7700-$7DFF (la zona de The Pepsi Challenge, que en MSX2 no
;  se usa).
;
;  V9_PRESENTE vale 2 mientras se ve SCREEN 5 (partida) y 0 en SCREEN
;  2, asi que fuera de la partida el juego hace exactamente lo de
;  siempre. V9_HAY_EXT = 2 hace que CARGAR_NIVEL llegue aqui.
;
;  VRAM (SCREEN 5, 128 bytes por linea, 4 paginas de 256 lineas):
;    paginas 0 y 1   pantalla que se ve y la que se compone (ventana
;                    del laberinto en (32,16), como en el TMS); debajo
;                    (lineas 192-239 de cada una) la cache de munecos
;    pagina 2, y 0-127    copia de la VRAM del TMS ($0000-$3FFF): con
;                    R#14 = 4 lo que el juego escribe en el TMS cae
;                    aqui; al volver a SCREEN 2 se copia a su sitio
;    pagina 2, y 128-223  las 91 losetas del MSX1 (16 por fila; tinta
;                    color 1, papel color 8)
;    pagina 2, y 224-247  otra fila de la cache de munecos
;    pagina 3        anillo de 16 x 16 losetas: la celda (f, c) del
;                    nivel en x = (c mod 16)*16, y = (f mod 16)*16
;  Paleta: 0-15 los del TMS, salvo el 8 (fondo del laberinto, segun
;  REGISTRO_NIVEL_ICONO_HUD), el 9 (fondo del recuadro del comecocos,
;  COLOR_ACTUAL) y el 3 y el 4, que hacen de colores 8 y 9 del TMS en
;  el marco (alli no se usan el 3 ni el 4 del TMS).
; ==============================================================

M2_Y_LOSETAS    EQU 640         ; pagina 2, linea 128
M2_Y_ANILLO     EQU 768         ; pagina 3
M2_VENTANA_X    EQU 32
M2_VENTANA_Y    EQU 16
M2_LOSETA_NEGRA EQU 66          ; loseta solida negra (fuera de la matriz)
M2_N_HUECOS     EQU 50          ; huecos de la cache de munecos

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
    ; en MSX2 solo Mad Mix Game, sin la opcion 3 (The Pepsi Challenge)
    XOR A
    LD HL, PEPSI_DIBUJAR_MENU.LINEA_3
    LD (HL), A
    INC HL
    LD (HL), A
    INC HL
    LD (HL), A
    LD A, $C3                   ; JP
    LD (PEPSI_DESPACHAR.SALTO), A
    XOR A
    LD (M2_COLA_N), A           ; la zona de Pepsi trae datos
    LD HL, M2_ISR
    LD (V9_ISR.SALTO_TMS + 1), HL
    LD A, 2
    LD (V9_HAY_EXT), A          ; 2: MSX2
    RET

; A = 8 pixeles del MSX1 -> 4 bytes de SCREEN 5 (bit a 1: color 1,
; bit a 0: color 8)
M2_BYTE:
    LD D, A
    LD B, 4
.PAR:
    LD A, $88
    RL D
    JR NC, .IZQUIERDA
    LD A, $18
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
    LD A, $C3                   ; JP
    LD (V9_TEXTO_EXT), A
    LD (V9_ACTOR_EXT), A
    LD HL, M2_TEXTO
    LD (V9_TEXTO_EXT + 1), HL
    LD HL, M2_ACTOR
    LD (V9_ACTOR_EXT + 1), HL
    CALL M2_ENTRAR
    LD A, 2
    LD (V9_PRESENTE), A
    LD A, MODO_JUEGO
    LD (V9_MODO), A
    XOR A
    LD (M2_NEGRO), A
    LD (M2_N_ACT), A
    LD (M2_COMPUESTA), A        ; la pagina oculta es del nivel anterior
    INC A
    LD (M2_NUEVO), A
    LD (M2_MARCO_PENDIENTE), A
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
    LD HL, M2_PALETA_JUEGO
    CALL M2_PALETA
    LD HL, M2_SUMAS             ; marco: nada convertido aun (todo negro)
    LD DE, M2_SUMAS + 1
    LD BC, 768 - 1
    LD (HL), 0
    LDIR
    LD A, $FF
    LD (M2_COLOR), A
    LD (M2_COLOR9), A
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
    LD HL, M2_PALETA_TMS        ; los colores vuelven a ser los del TMS
    CALL M2_PALETA
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

; HL -> 16 colores para el V9938
M2_PALETA:
    DI
    XOR A
    LD B, 16
    CALL M2_REG
    LD BC, 32 * 256 + $9A
    OTIR
    EI
    RET

; --------------------------------------------------------------
;  M2_TIC (V9_TIC): en lugar del volcado al TMS, una vez por tic.
;  Ensena la pagina compuesta en el tic anterior y compone la otra:
;  las losetas visibles que han cambiado al anillo, la ventana del
;  anillo a la pagina oculta, los munecos apuntados en este tic y el
;  recuadro del comecocos. Despues repasa un trozo del marco. El VDP
;  trabaja mientras sigue el juego.
; --------------------------------------------------------------
M2_TIC:
    LD A, (M2_NEGRO)
    AND A
    JR Z, .COMPONER
    XOR A
    LD (M2_N_ACT), A
    RET
.COMPONER:
    LD A, (M2_COMPUESTA)
    AND A
    JR Z, .LISTA
    ; --- la pagina oculta ya tiene la ventana del tic anterior (el
    ; VDP la ha copiado mientras seguia el juego): sus munecos y el
    ; recuadro del comecocos, y se ensena ---
    CALL M2_ACTORES
    LD A, (M2_OCULTA)
    LD (M2_CMD_CUADRO + 7), A
    LD HL, M2_CMD_CUADRO
    CALL M2_VDP_CMD
    CALL M2_ESPERAR_CE
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
.LISTA:
    ; --- los munecos de este tic se dibujan en el siguiente, sobre la
    ; ventana que se copia ahora ---
    LD HL, M2_LISTA
    LD DE, M2_LISTA2
    LD BC, 4 * 10
    LDIR
    LD HL, M2_N_ACT
    LD A, (HL)
    LD (HL), 0
    LD (M2_N2), A
    LD HL, M2_TICNUM
    INC (HL)
    ; --- color del laberinto (el fondo del TMS) en el color 8 y el
    ; del recuadro del comecocos en el 9 ---
    LD A, (REGISTRO_NIVEL_ICONO_HUD)
    CALL CONSULTAR_COLOR_VDP
    LD HL, M2_COLOR
    LD B, 8
    CALL M2_UN_COLOR
    LD A, (COLOR_ACTUAL)
    CALL CONSULTAR_COLOR_VDP
    LD HL, M2_COLOR9
    LD B, 9
    CALL M2_UN_COLOR
    ; --- nivel recien cargado: el anillo y la cache no valen ---
    LD B, 16                    ; celdas del marco que se repasan
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
    LD HL, M2_CACHE_SLOT
.INVALIDAR_CACHE:
    LD (HL), $FF
    INC L
    DJNZ .INVALIDAR_CACHE
    LD B, 0                     ; el marco entero (336 celdas)
.ESQUINA:
    LD A, B
    LD (M2_REPASO), A
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
    CALL M2_FILA_ANILLO
    LD HL, M2_F
    INC (HL)
    POP BC
    DJNZ .FILA
    ; --- la ventana del anillo a la pagina oculta (el ultimo trozo
    ; se queda copiando mientras sigue el juego) ---
    CALL M2_VENTANA
    LD A, 1
    LD (M2_COMPUESTA), A
    ; --- el marco: los puntos recien escritos y un trozo del resto ---
    LD HL, V9_MARCADOR_SUCIO
    LD A, (HL)
    AND A
    CALL NZ, M2_PUNTOS
    LD A, (M2_REPASO)
    LD B, A
    AND A
    JP NZ, M2_MARCO
    ; sigue en M2_MARCO_ENTERO

; El marco entero (336 celdas)
M2_MARCO_ENTERO:
    XOR A
    LD (M2_MARCO_PENDIENTE), A
    LD B, 7
.TODO:
    PUSH BC
    LD B, 48
    CALL M2_MARCO
    POP BC
    DJNZ .TODO
    RET

; --------------------------------------------------------------
;  Munecos. MOTOR_ACTORES los dibujaba en el buffer del TMS mezclando
;  con mascara y tinta (sprites de 24 x 24, 6 bytes por fila: 3 de
;  mascara, bit a 1 = se queda el fondo, y 3 de tinta). Aqui se
;  apuntan (M2_ACTOR) y en el tic se copian con LMMM y transparencia
;  desde una cache en la VRAM: tinta color 1, el resto de la mascara
;  color 8 (el fondo del laberinto) y lo transparente color 0.
; --------------------------------------------------------------
; M2_ACTOR (V9_ACTOR_EXT): B = sprite, E = columna, D = fila,
; A = indicadores. Mismos filtros que el motor; conserva todo.
M2_ACTOR:
    PUSH HL
    PUSH AF
    LD A, (M2_N_ACT)
    CP 10
    JR NC, .FIN
    LD A, B
    CP 64
    JR NC, .FIN
    LD A, E
    CP 4
    JR C, .FIN
    CP 116
    JR NC, .FIN
    LD A, (M2_N_ACT)
    INC A
    LD (M2_N_ACT), A
    DEC A
    ADD A, A
    ADD A, A
    ADD A, LOW M2_LISTA
    LD L, A
    LD A, 0
    ADC A, HIGH M2_LISTA
    LD H, A
    LD (HL), B
    INC HL
    LD (HL), E
    INC HL
    LD (HL), D
    INC HL
    POP AF
    LD (HL), A
    POP HL
    RET
.FIN:
    POP AF
    POP HL
    RET

; Los munecos del tic anterior, en orden (el ultimo queda encima). Si
; uno se repite igual mas adelante, solo se dibuja alli: queda lo mismo.
M2_ACTORES:
    LD A, (M2_N2)
    AND A
    RET Z
    LD B, A
    LD IX, M2_LISTA2
.ACTOR:
    PUSH BC
    DEC B
    JR Z, .DIBUJAR
    PUSH IX
    POP HL
.MIRAR:
    LD DE, 4
    ADD HL, DE
    PUSH HL
    PUSH IX
    POP DE
    LD C, 4
.BYTE:
    LD A, (DE)
    CP (HL)
    JR NZ, .DISTINTO
    INC DE
    INC HL
    DEC C
    JR NZ, .BYTE
    POP HL
    JR .SALTAR
.DISTINTO:
    POP HL
    DJNZ .MIRAR
.DIBUJAR:
    CALL M2_UN_ACTOR
.SALTAR:
    POP BC
    LD DE, 4
    ADD IX, DE
    DJNZ .ACTOR
    RET

; IX -> sprite, columna, fila, indicadores
M2_UN_ACTOR:
    LD L, (IX + 0)
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    LD DE, PTR_TABLA_SPRITES
    ADD HL, DE
    LD E, (HL)
    INC HL
    LD D, (HL)
    INC HL
    LD (M2_A_PTR), DE
    LD A, (HL)
    LD (M2_A_FL), A
    INC HL
    LD A, (HL)
    CP 25
    JR C, .ALTO
    LD A, 24
.ALTO:
    LD (M2_A_ALTO), A
    ; clave de la cache: sprite * 4 + reflejo pedido (bits 6-7)
    LD A, (IX + 3)
    RLCA
    RLCA
    AND 3
    LD C, A
    LD A, (IX + 0)
    ADD A, A
    ADD A, A
    OR C
    LD (M2_A_CLAVE), A
    CALL M2_HUECO               ; A = hueco de la cache con el dibujo
    CALL M2_HUECO_XY            ; HL = y, C = x
    LD (M2_CMD_ACTOR + 2), HL   ; SY (se le suman las filas que no se ven)
    LD A, C
    LD (M2_A_SX), A
    ; --- horizontal: x = columna * 2; el motor escribe 3 bytes desde
    ; x AND $F8 con el dibujo desplazado a la derecha x AND 7, o con el
    ; reflejo y hueco h != 0, a la izquierda (h - x) AND 7 ---
    LD A, (IX + 1)
    ADD A, A
    LD E, A                     ; x
    AND $F8
    LD D, A                     ; x AND $F8
    LD A, (M2_A_FL)
    AND 7
    JR Z, .DERECHA
    BIT 7, (IX + 3)
    JR Z, .DERECHA
    SUB E
    AND 7
    LD C, A
    LD A, D
    SUB C
    JR .ORIGEN
.DERECHA:
    LD A, E
.ORIGEN:
    LD L, A                     ; x de la columna 0 del dibujo
    ; desde max(x AND $F8, 32, origen) ...
    LD A, D
    CP M2_VENTANA_X
    JR NC, .IZQ_1
    LD A, M2_VENTANA_X
.IZQ_1:
    CP L
    JR NC, .IZQ_2
    LD A, L
.IZQ_2:
    LD H, A
    ; ... hasta min(x AND $F8 + 24, 224, origen + 24)
    LD A, D
    ADD A, 24
    CP M2_VENTANA_X + 192
    JR C, .DER_1
    LD A, M2_VENTANA_X + 192
.DER_1:
    LD C, A
    LD A, L
    ADD A, 24
    CP C
    JR C, .DER_2
    LD A, C
.DER_2:
    SUB H
    RET Z
    RET C
    LD (M2_CMD_ACTOR + 8), A    ; NX
    LD A, H
    LD (M2_CMD_ACTOR + 4), A    ; DX
    SUB L
    LD C, A
    LD A, (M2_A_SX)
    ADD A, C
    LD (M2_CMD_ACTOR + 0), A    ; SX
    ; --- vertical: fila D (par); si se pasa de 255 asoma por arriba
    ; (D - 256), si no se recorta a las 144 filas de la ventana ---
    LD A, (IX + 2)
    AND $FE
    LD D, A
    LD A, (M2_A_ALTO)
    ADD A, D
    JR NC, .SIN_VUELTA
    AND A
    RET Z
    LD C, A                     ; filas que se ven
    LD B, 0                     ; desde la fila 0 de la ventana
    LD A, D
    NEG                         ; filas del dibujo que no se ven
    JR .VERTICAL
.SIN_VUELTA:
    LD C, A
    LD A, D
    CP 144
    RET NC
    LD A, C
    CP 144
    JR C, .ABAJO
    LD A, 144
.ABAJO:
    SUB D
    LD C, A
    LD B, D
    XOR A
.VERTICAL:
    LD HL, (M2_CMD_ACTOR + 2)
    ADD A, L
    LD L, A
    ADC A, H
    SUB L
    LD H, A
    LD (M2_CMD_ACTOR + 2), HL
    LD A, B
    ADD A, M2_VENTANA_Y
    LD (M2_CMD_ACTOR + 6), A    ; DY
    LD A, (M2_OCULTA)
    LD (M2_CMD_ACTOR + 7), A
    LD A, C
    LD (M2_CMD_ACTOR + 10), A   ; NY
    LD HL, M2_CMD_ACTOR
    JP M2_VDP_CMD

; M2_HUECO: A = hueco de la cache con el dibujo de M2_A_CLAVE; si no
; esta, se convierte en uno que no se haya usado en este tic.
M2_HUECO:
    LD A, (M2_A_CLAVE)
    LD L, A
    LD H, HIGH M2_CACHE_SLOT
    LD A, (HL)
    CP M2_N_HUECOS
    JR NC, .FALLO
    LD C, A
    LD B, 0
    LD HL, M2_HUECO_CLAVE
    ADD HL, BC
    LD A, (M2_A_CLAVE)
    CP (HL)
    LD A, C
    JR Z, .USADO
.FALLO:
    LD A, (M2_TICNUM)
    LD D, A
    LD A, (M2_CACHE_SIG)
    LD E, A
    LD B, M2_N_HUECOS
.BUSCAR:
    LD HL, M2_HUECO_USO
    LD A, L
    ADD A, E
    LD L, A
    ADC A, H
    SUB L
    LD H, A
    LD A, (HL)
    CP D
    JR NZ, .LIBRE
    INC E
    LD A, E
    CP M2_N_HUECOS
    JR C, .OTRO
    LD E, 0
.OTRO:
    DJNZ .BUSCAR
.LIBRE:
    LD A, E
    INC A
    CP M2_N_HUECOS
    JR C, .SIGUIENTE
    XOR A
.SIGUIENTE:
    LD (M2_CACHE_SIG), A
    LD C, E
    LD B, 0
    LD HL, M2_HUECO_CLAVE
    ADD HL, BC
    LD E, (HL)                  ; la clave que tenia
    LD A, (M2_A_CLAVE)
    LD (HL), A
    LD L, E
    LD H, HIGH M2_CACHE_SLOT
    LD A, (HL)
    CP C
    JR NZ, .NO_ERA
    LD (HL), $FF
.NO_ERA:
    LD A, (M2_A_CLAVE)
    LD L, A
    LD (HL), C
    PUSH BC
    LD A, C
    CALL M2_CONVERTIR
    POP BC
    LD A, C
.USADO:
    LD C, A
    LD B, 0
    LD HL, M2_HUECO_USO
    ADD HL, BC
    LD A, (M2_TICNUM)
    LD (HL), A
    LD A, C
    RET

; A = hueco -> HL = linea, C = x (10 huecos de 24 px por fila)
M2_HUECO_XY:
    LD HL, M2_FILAS_CACHE
    LD C, A
.DIEZ:
    LD A, C
    SUB 10
    JR C, .FILA
    LD C, A
    INC HL
    INC HL
    JR .DIEZ
.FILA:
    LD A, (HL)
    INC HL
    LD H, (HL)
    LD L, A
    LD A, C
    ADD A, A
    ADD A, C
    ADD A, A
    ADD A, A
    ADD A, A
    LD C, A
    RET

; M2_CONVERTIR: A = hueco. El sprite de M2_A_PTR, con el reflejo que
; pide IX + 3 (la RAM puede tenerlo ya reflejado: indicadores del
; sprite), a 4 bpp en la VRAM.
M2_CONVERTIR:
    CALL M2_HUECO_XY
    LD (M2_CV_Y), HL
    SRL C
    LD A, C
    LD (M2_CV_X), A
    LD A, (M2_A_FL)
    XOR (IX + 3)
    AND $C0
    LD (M2_CV_GIRO), A
    ; bit 6: espejo vertical (el motor intercambia las filas de 6 bytes
    ; de los extremos hacia el centro): se leen de abajo arriba
    LD HL, (M2_A_PTR)
    LD DE, 0
    AND $40
    JR Z, .PASO
    LD A, (M2_A_ALTO)
    DEC A
    LD E, A
    ADD A, A
    ADD A, E
    ADD A, A
    LD E, A
    ADD HL, DE
    LD DE, -12
.PASO:
    LD (M2_CV_PASO), DE
    LD A, (M2_A_ALTO)
    LD B, A
.FILA:
    PUSH BC
    LD DE, M2_CV_M
    LD BC, 6
    LDIR
    LD DE, (M2_CV_PASO)
    ADD HL, DE
    PUSH HL
    ; bit 7: espejo horizontal (el motor invierte el orden de los 3
    ; bytes y los bits de cada uno, en la mascara y en la tinta)
    LD A, (M2_CV_GIRO)
    RLA
    CALL C, M2_ESPEJO
    LD HL, M2_CV_M
    LD DE, M2_CV_SALIDA
    LD B, 3
.BYTE:
    PUSH BC
    LD C, (HL)                  ; mascara
    INC HL
    INC HL
    INC HL
    LD B, (HL)                  ; tinta
    DEC HL
    DEC HL
    PUSH HL
    LD L, 4
.PAR:
    CALL .PIXEL
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD H, A
    CALL .PIXEL
    OR H
    LD (DE), A
    INC DE
    DEC L
    JR NZ, .PAR
    POP HL
    POP BC
    DJNZ .BYTE
    DI
    LD HL, (M2_CV_Y)
    LD A, (M2_CV_X)
    LD C, A
    CALL M2_DIRECCION
    LD HL, M2_CV_SALIDA
    LD B, 12
    CALL M2_SACAR
    CALL M2_R14
    EI
    LD HL, (M2_CV_Y)
    INC HL
    LD (M2_CV_Y), HL
    POP HL
    POP BC
    DJNZ .FILA
    RET
; pixel siguiente: tinta -> 1; mascara a 0 -> 8; si no, 0
.PIXEL:
    SLA B
    JR C, .TINTA
    SLA C
    LD A, 0
    RET C
    LD A, 8
    RET
.TINTA:
    SLA C
    LD A, 1
    RET

; HL = linea (0-1023), C = byte en la linea: escritura en la VRAM.
; Con interrupciones cerradas; despues, M2_R14.
M2_DIRECCION:
    LD A, L
    RLA
    LD A, H
    RLA
    OUT ($99), A
    LD A, 14 + $80
    OUT ($99), A
    LD A, L
    RRCA
    AND $80
    OR C
    OUT ($99), A
    LD A, L
    RRCA
    AND $3F
    OR $40
    OUT ($99), A
    RET

; R#14 = 4: el juego vuelve a escribir en la copia del TMS
M2_R14:
    LD A, $10000 >> 14
    OUT ($99), A
    LD A, 14 + $80
    OUT ($99), A
    RET

; B bytes de HL a la VRAM, sin prisa (mas de 29 ciclos entre OUT)
M2_SACAR:
    LD A, (HL)
    OUT ($98), A
    INC HL
    DJNZ M2_SACAR
    RET

; --------------------------------------------------------------
;  Marco (todo lo que no es la ventana: puntos, vidas, icono...). El
;  juego lo sigue escribiendo en la copia del TMS; cada tic se repasa
;  un trozo comparando una suma de cada celda y las que cambian se
;  pasan a 4 bpp en las dos paginas.
; --------------------------------------------------------------
; B = celdas que se repasan
M2_MARCO:
    PUSH BC
    LD HL, (M2_MARCO_C)         ; L = columna, H = fila
    INC L
    LD A, L
    CP 32
    JR C, .VENTANA
    LD L, 0
    INC H
    LD A, H
    CP 24
    JR C, .VENTANA
    LD H, 0
.VENTANA:
    LD A, H
    CP 2
    JR C, .FUERA
    CP 20
    JR NC, .FUERA
    LD A, L
    CP 4
    JR C, .FUERA
    CP 28
    JR NC, .FUERA
    LD L, 28                    ; se salta la ventana
.FUERA:
    LD (M2_MARCO_C), HL
    EX DE, HL
    CALL M2_LEER
    CALL M2_SUMA
    LD A, (HL)
    CP C
    JR NZ, .CAMBIA
    INC HL
    LD A, (HL)
    CP B
    JR Z, .IGUAL
    DEC HL
.CAMBIA:
    LD (HL), C
    INC HL
    LD (HL), B
    CALL M2_PINTAR
.IGUAL:
    DI
    CALL M2_COLA_SERVIR
    EI
    POP BC
    DJNZ M2_MARCO
    RET

; D = fila, E = columna -> HL -> sus 2 bytes de suma en M2_SUMAS: las
; filas 0-1 y 20-23 enteras (celdas 0-191) y las columnas 0-3 y 28-31
; de las filas 2-19 (celdas 192-335). Conserva BC y DE.
M2_SUMA:
    LD A, D
    CP 2
    JR C, .ANCHA
    CP 20
    JR C, .MEDIO
    SUB 18                      ; filas 20-23: como 2-5
    JR .ANCHA
.MEDIO:
    SUB 2
    ADD A, A
    ADD A, A
    ADD A, A
    LD L, A
    LD A, E
    AND 7                       ; 0-3 y 28-31 -> 0-7
    OR L
    ADD A, 192
    LD L, A
    LD A, 0
    ADC A, A
    LD H, A
    JR .DOBLE
.ANCHA:
    RRCA
    RRCA
    RRCA
    OR E
    LD L, A
    LD H, 0
.DOBLE:
    ADD HL, HL
    LD A, H
    ADD A, HIGH M2_SUMAS
    LD H, A
    RET

; D = fila, E = columna: patron y color de la copia del TMS a
; M2_CELDA16; BC = una suma de Fletcher de los 16 bytes. Conserva DE.
M2_LEER:
    DI
    LD A, E
    ADD A, A
    ADD A, A
    ADD A, A
    LD C, A
    OUT ($99), A
    LD A, D
    OUT ($99), A
    LD HL, M2_CELDA16
    CALL .OCHO
    LD A, C
    OUT ($99), A
    LD A, D
    ADD A, $20
    OUT ($99), A
    CALL .OCHO
    EI
    PUSH DE
    LD HL, M2_CELDA16
    LD DE, 0
    LD B, 16
.SUMAR:
    LD A, E
    ADD A, (HL)
    LD E, A
    ADD A, D
    LD D, A
    INC HL
    DJNZ .SUMAR
    LD B, D
    LD C, E
    POP DE
    RET
.OCHO:
    LD B, 8
.BYTE:
    IN A, ($98)
    LD (HL), A
    INC HL
    DJNZ .BYTE
    RET

; D = fila, E = columna: M2_CELDA16 a 4 bpp en las dos paginas
M2_PINTAR:
    PUSH DE
    LD HL, M2_CELDA16
    LD DE, M2_CELDA32
    LD B, 8
.LINEA:
    PUSH BC
    PUSH HL
    LD BC, 8
    ADD HL, BC
    LD A, (HL)                  ; color: tinta y papel
    LD C, A
    RRCA
    RRCA
    RRCA
    RRCA
    CALL M2_MAPA
    LD B, A
    LD A, C
    CALL M2_MAPA
    LD C, A
    POP HL
    PUSH HL
    LD H, (HL)                  ; patron
    LD L, 4
.PAR:
    SLA H
    LD A, C
    JR NC, .IZQUIERDA
    LD A, B
.IZQUIERDA:
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    SLA H
    JR NC, .PAPEL
    OR B
    JR .DOS
.PAPEL:
    OR C
.DOS:
    LD (DE), A
    INC DE
    DEC L
    JR NZ, .PAR
    POP HL
    INC HL
    POP BC
    DJNZ .LINEA
    POP DE
    ; linea 8 * fila + l, byte 4 * columna; R#14 = pagina * 2 + fila / 16
    LD A, E
    ADD A, A
    ADD A, A
    LD (M2_BAJO), A
    LD A, D
    AND 15
    ADD A, A
    ADD A, A
    OR $40
    LD (M2_ALTO), A
    LD C, 0
.PAGINA:
    LD A, D
    RRCA
    RRCA
    RRCA
    RRCA
    AND 1
    ADD A, C
    ADD A, C
    DI
    OUT ($99), A
    LD A, 14 + $80
    OUT ($99), A
    LD HL, M2_CELDA32
    LD B, 0
.L:
    PUSH BC
    LD A, B
    RRCA
    AND $80
    LD C, A
    LD A, (M2_BAJO)
    OR C
    OUT ($99), A
    LD A, B
    SRL A
    LD C, A
    LD A, (M2_ALTO)
    ADD A, C
    OUT ($99), A
    LD B, 4
    CALL M2_SACAR
    POP BC
    INC B
    LD A, B
    CP 8
    JR NZ, .L
    CALL M2_R14
    EI
    INC C
    LD A, C
    CP 2
    JR C, .PAGINA
    RET

; A (nibble bajo) = color del TMS -> color del V9938 en el marco
M2_MAPA:
    AND $0F
    PUSH HL
    LD HL, M2_MAPA_MARCO
    ADD A, L
    LD L, A
    ADC A, H
    SUB L
    LD H, A
    LD A, (HL)
    POP HL
    RET

; M2_FILA_ANILLO: la fila M2_F, columnas M2_C0 a M2_C0 + 12 (mod 32),
; al anillo. Cada hueco recuerda la loseta (M2_ANILLO_VALOR) y una
; clave de la celda (M2_ANILLO_FILA: fila AND $F0, mas 8 si la columna
; es 16-31); si no coinciden, la loseta se copia al hueco.
M2_FILA_ANILLO:
    LD A, (M2_F)
    LD D, A
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD C, A                     ; (fila AND 15) * 16
    LD A, D
    AND $F0
    LD E, A
    LD A, D
    LD D, E                     ; D = fila AND $F0
    CP FILAS_MATRIZ
    JR C, .MATRIZ
    LD HL, M2_CELDA32           ; fuera de la matriz: losetas negras
    LD (HL), M2_LOSETA_NEGRA
    PUSH DE
    PUSH BC
    LD DE, M2_CELDA32 + 1
    LD BC, 31
    LDIR
    POP BC
    POP DE
    LD HL, M2_CELDA32
    JR .PUNTERO
.MATRIZ:
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD A, L
    ADD A, LOW MATRIZ_NIVEL
    LD L, A
    LD A, H
    ADC A, HIGH MATRIZ_NIVEL
    LD H, A
.PUNTERO:
    LD A, (M2_C0)
    AND 31
    LD E, A                     ; columna
    ADD A, L
    LD L, A
    ADC A, H
    SUB L
    LD H, A
    LD B, 13
.CELDA:
    LD A, (HL)
    AND $7F                     ; bit 7 = comida
    EX AF, AF'                  ; A' = loseta
    PUSH HL
    LD A, E
    AND 15
    OR C
    LD L, A                     ; hueco
    LD H, HIGH M2_ANILLO_FILA
    LD A, E
    AND $10
    RRCA
    OR D                        ; clave de la celda
    CP (HL)
    JR NZ, .CAMBIA
    DEC H
    EX AF, AF'
    CP (HL)
    JR Z, .IGUAL
    EX AF, AF'
    INC H
.CAMBIA:
    LD (HL), A
    DEC H
    EX AF, AF'
    LD (HL), A
    CALL M2_COPIAR_LOSETA
.IGUAL:
    POP HL
    INC HL
    INC E
    LD A, E
    CP 32
    JR C, .SIGUE
    LD E, 0
    LD A, L
    SUB 32
    LD L, A
    JR NC, .SIGUE
    DEC H
.SIGUE:
    DJNZ .CELDA
    RET

; M2_VENTANA: 192 x 144 del anillo desde (M2_SX, M2_SY) a la ventana
; de la pagina oculta, en 1-4 trozos segun corte por los bordes.
M2_VENTANA:
    CALL M2_COLA_VACIAR
    LD HL, M2_COLA
    LD (M2_COLA_SIG), HL
    LD (M2_COLA_FIN), HL
    CALL .X_TODO
    DI
    CALL M2_COLA_SERVIR         ; el primer trozo ya; el resto, la ISR
    EI
    RET
.X_TODO:
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
    CALL M2_ENCOLAR
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
    CALL M2_COLA_VACIAR
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

M2_CMD_ACTOR:                   ; LMMM con transparencia: cache -> pagina oculta
    DW 0, 0, 0, 0, 0, 0
    DB 0, 0, $98
M2_CMD_CUADRO:                  ; LMMV OR 1: recuadro del comecocos, color 8 -> 9
    DW 0, 0, 128, 80, 16, 16
    DB 1, 0, $82

; Paleta en partida: la del TMS con los colores 8 y 9 tambien en el 3
; y el 4 (el marco); el 8 y el 9 se cambian en cada tic
M2_PALETA_JUEGO:
    DB $00, 0,  $00, 0,  $11, 6,  $71, 1,  $73, 3,  $27, 3,  $51, 1,  $27, 6
    DB $71, 1,  $73, 3,  $61, 6,  $64, 6,  $11, 4,  $65, 2,  $55, 5,  $77, 7
; Colores del TMS en el marco: el 3 y el 4 (no se usan) se quedan en
; el 2 y el 5; el 8 y el 9 pasan al 3 y al 4
M2_MAPA_MARCO:
    DB 0, 1, 2, 2, 5, 5, 6, 7, 3, 4, 10, 11, 12, 13, 14, 15
; Lineas de las 5 filas de la cache de munecos (10 huecos de 24 x 24)
M2_FILAS_CACHE:
    DW 192, 216, 256 + 192, 256 + 216, 512 + 224

; Variables
M2_EN_5:      DB 0              ; 1: SCREEN 5
M2_NEGRO:     DB 0              ; 1: fin de partida, no se compone
M2_NUEVO:     DB 0              ; 1: nivel recien cargado
M2_OCULTA:    DB 1              ; pagina que se compone
M2_COMPUESTA: DB 0              ; 1: la pagina oculta ya esta compuesta
M2_COLOR:     DB $FF            ; color del TMS que hay en el color 8
M2_COLOR9:    DB $FF            ; y en el 9
M2_R1:        DB $E2
M2_SX:        DB 0
M2_SY:        DB 0
M2_C0:        DB 0
M2_C:         DB 0
M2_F:         DB 0
M2_T0:        DB 0
M2_T:         DB 0
M2_TICNUM:    DB 0
M2_REPASO:    DB 0              ; celdas del marco en este tic (0: todas)
M2_N_ACT:     DB 0
M2_MARCO_PENDIENTE: DB 0       ; 1: el marco aun no se ha pasado entero
M2_CACHE_SIG: DB 0
M2_MARCO_C:   DW 0              ; columna, fila

FIN_MSX2:
    ASSERT FIN_MSX2 <= $FC00

; Tablas (no se cargan; zona de The Pepsi Challenge, que en MSX2 no se
; usa). Anillo: loseta, fila y columna de la celda que hay en cada
; hueco; suma de cada celda del marco; hueco de la cache de cada
; sprite y reflejo ($FF: no esta).
M2_ANILLO_VALOR   EQU $7700
M2_ANILLO_FILA    EQU $7800
M2_COLA           EQU $7900     ; 4 comandos de 15 bytes
M2_COLA_N         EQU M2_COLA + 60
M2_COLA_SIG       EQU M2_COLA_N + 1
M2_COLA_FIN       EQU M2_COLA_SIG + 2
M2_HUECO_CLAVE    EQU M2_COLA_FIN + 2         ; clave del dibujo de cada hueco
M2_HUECO_USO      EQU M2_HUECO_CLAVE + M2_N_HUECOS ; tic en que se uso
M2_LISTA2         EQU M2_HUECO_USO + M2_N_HUECOS   ; munecos del tic anterior
M2_N2             EQU M2_LISTA2 + 4 * 10
FIN_M2_7900       EQU M2_N2 + 1
    ASSERT FIN_M2_7900 <= M2_SUMAS
M2_SUMAS          EQU $7A00     ; 336 x 2 bytes
M2_CACHE_SLOT     EQU $7D00
; Variables de trabajo (no se cargan; tambien de The Pepsi Challenge)
M2_LISTA          EQU $7E00     ; 10 munecos: sprite, columna, fila, indicadores
M2_CV_M           EQU M2_LISTA + 4 * 10       ; fila del sprite
M2_CV_SALIDA      EQU M2_CV_M + 6                  ; y a 4 bpp
M2_CELDA16        EQU M2_CV_SALIDA + 12            ; patron y color de una celda
M2_CELDA32        EQU M2_CELDA16 + 16              ; y a 4 bpp
M2_A_PTR          EQU M2_CELDA32 + 32
M2_A_FL           EQU M2_A_PTR + 2
M2_A_ALTO         EQU M2_A_FL + 1
M2_A_CLAVE        EQU M2_A_ALTO + 1
M2_A_SX           EQU M2_A_CLAVE + 1
M2_CV_Y           EQU M2_A_SX + 1
M2_CV_X           EQU M2_CV_Y + 2
M2_CV_GIRO        EQU M2_CV_X + 1
M2_BAJO           EQU M2_CV_GIRO + 1
M2_ALTO           EQU M2_BAJO + 1
M2_TX_FILA        EQU M2_ALTO + 1
M2_TX_COLUMNA     EQU M2_TX_FILA + 1
M2_CV_PASO        EQU M2_TX_COLUMNA + 1
FIN_M2_TRABAJO    EQU M2_CV_PASO + 2
    ASSERT FIN_M2_TRABAJO <= TRASPUESTA

; --------------------------------------------------------------
;  Parte alta: en $7F00-$7FEF (zona de The Pepsi Challenge), con su
;  propio fragmento en TABLA_M2. Se ensambla en $FC00, donde no se
;  guarda nada mas.
; --------------------------------------------------------------
    ORG $FC00
M2_ALTA_ORIGEN:
    DISP $7E80
M2_ALTA:

; --------------------------------------------------------------
;  M2_ISR: la ISR del TMS con MSX2 (V9_ISR salta aqui). Si el juego
;  espera en un HALT (no esta escribiendo en la VRAM) y se ve SCREEN
;  5, despues de la ISR del juego se repasa un trozo del marco: asi
;  se ve lo que cambia mientras no hay tics (READY?, pausas).
; --------------------------------------------------------------
M2_ISR:
    PUSH AF
    LD A, (V9_PRESENTE)
    CP 2
    JR Z, .MSX2
    POP AF
    JP ENTRADA_INTERRUPCION_VBLANK
.MSX2:
    POP AF
    CALL ENTRADA_INTERRUPCION_VBLANK
    PUSH AF
    PUSH BC
    PUSH DE
    PUSH HL
    DI
    CALL M2_COLA_SERVIR         ; siguiente trozo de la ventana
    LD HL, 10
    ADD HL, SP
    LD A, (HL)
    INC HL
    LD H, (HL)
    LD L, A
    DEC HL
    LD A, (HL)                  ; la instruccion de antes de la vuelta
    CP $76                      ; HALT
    LD B, 16
    CALL Z, M2_MARCO
    POP HL
    POP DE
    POP BC
    POP AF
    EI
    RET

; --------------------------------------------------------------
;  Cola de comandos del VDP (los trozos de la ventana): se van
;  lanzando sin esperar desde la ISR y el repaso del marco; cualquier
;  otro comando (M2_VDP_CMD) acaba antes la cola.
; --------------------------------------------------------------
; HL -> 15 bytes para R#32-R#46: a la cola
M2_ENCOLAR:
    LD DE, (M2_COLA_FIN)
    LD BC, 15
    LDIR
    LD (M2_COLA_FIN), DE
    LD HL, M2_COLA_N
    INC (HL)
    RET

; Con interrupciones cerradas: si hay algo en la cola y el VDP esta
; libre, lanza el siguiente. Conserva todo menos AF.
M2_COLA_SERVIR:
    LD A, (M2_COLA_N)
    AND A
    RET Z
    PUSH BC
    PUSH HL
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
    BIT 0, B
    JR NZ, .OCUPADO
    LD A, 32
    OUT ($99), A
    LD A, 17 + $80
    OUT ($99), A
    LD HL, (M2_COLA_SIG)
    LD BC, 15 * 256 + $9B
    OTIR
    LD (M2_COLA_SIG), HL
    LD HL, M2_COLA_N
    DEC (HL)
.OCUPADO:
    POP HL
    POP BC
    RET

; Lanza todo lo que quede en la cola (el ultimo puede seguir en marcha)
M2_COLA_VACIAR:
    LD A, (M2_COLA_N)
    AND A
    RET Z
    DI
    CALL M2_COLA_SERVIR
    EI
    JR M2_COLA_VACIAR

; --------------------------------------------------------------
;  M2_TEXTO (V9_TEXTO_EXT): despues de DIBUJAR_TEXTO_VRAM, con HL =
;  direccion del texto en el TMS (H = fila) y DE = el texto (numero
;  de entradas, un byte mas y las entradas; un codigo < $20 salta esas
;  columnas). Las celdas escritas pasan ya a las dos paginas; en la
;  ventana duran hasta que se compone otra vez, como en el TMS.
; --------------------------------------------------------------
M2_TEXTO:
    LD A, (M2_MARCO_PENDIENTE)  ; nivel nuevo: el marco antes que el texto
    AND A
    JR Z, .MARCO_HECHO
    PUSH HL
    PUSH DE
    CALL M2_MARCO_ENTERO
    POP DE
    POP HL
.MARCO_HECHO:
    LD A, H
    CP 24
    RET NC
    LD (M2_TX_FILA), A
    LD A, L
    RRCA
    RRCA
    RRCA
    AND 31
    LD (M2_TX_COLUMNA), A
    LD A, (DE)
    AND A
    RET Z
    LD B, A
    INC DE
    INC DE
.ENTRADA:
    LD A, (DE)
    INC DE
    CP $20
    JR NC, .LETRA
    LD HL, M2_TX_COLUMNA
    ADD A, (HL)
    LD (HL), A
    JR .SIGUE
.LETRA:
    LD A, (M2_TX_COLUMNA)
    CP 32
    JR NC, .SIGUE_1
    PUSH BC
    PUSH DE
    LD E, A
    LD A, (M2_TX_FILA)
    LD D, A
    CALL M2_LEER                ; sin tocar M2_SUMAS (solo es del marco)
    CALL M2_PINTAR
    POP DE
    POP BC
.SIGUE_1:
    LD HL, M2_TX_COLUMNA
    INC (HL)
.SIGUE:
    DJNZ .ENTRADA
    RET

; Los puntos (filas 22-23, columnas 22-27) en cuanto se escriben
M2_PUNTOS:
    LD (HL), 0
    LD DE, 22 * 256 + 22
.CELDA:
    PUSH DE
    CALL M2_FORZAR
    POP DE
    INC E
    LD A, E
    CP 28
    JR C, .CELDA
    LD E, 22
    INC D
    LD A, D
    CP 24
    JR C, .CELDA
    RET

; D = fila, E = columna: la celda a las dos paginas tal como este
M2_FORZAR:
    CALL M2_LEER
    CALL M2_SUMA
    LD (HL), C
    INC HL
    LD (HL), B
    JP M2_PINTAR

; A = loseta, L = hueco: HMMM de la loseta (pagina 2) al hueco
; (pagina 3). Conserva BC y DE.
M2_COPIAR_LOSETA:
    PUSH BC
    PUSH DE
    LD C, A
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
    CALL M2_VDP_CMD
    POP DE
    POP BC
    RET

; A = byte de color del TMS (papel en el nibble bajo), B = color del
; V9938 que lo imita, HL -> el que tiene ahora
M2_UN_COLOR:
    AND $0F
    CP (HL)
    RET Z
    LD (HL), A
    ADD A, A
    LD E, A
    LD D, 0
    LD HL, M2_PALETA_TMS
    ADD HL, DE
    DI
    LD A, B
    LD B, 16
    CALL M2_REG
    LD A, (HL)
    OUT ($9A), A
    INC HL
    LD A, (HL)
    OUT ($9A), A
    EI
    RET

; espejo horizontal de la fila en M2_CV_M (mascara y tinta): orden de
; los 3 bytes al reves y bits de cada byte en espejo, como el motor
M2_ESPEJO:
    LD HL, M2_CV_M
    CALL .CAMBIAR
    LD HL, M2_CV_M + 3
    CALL .CAMBIAR
    LD HL, M2_CV_M
    LD E, 6
.INVERTIR:
    LD C, (HL)
    LD B, 8
.BIT:
    RR C
    RLA
    DJNZ .BIT
    LD (HL), A
    INC HL
    DEC E
    JR NZ, .INVERTIR
    RET
.CAMBIAR:
    LD A, (HL)
    INC HL
    INC HL
    LD C, (HL)
    LD (HL), A
    DEC HL
    DEC HL
    LD (HL), C
    RET
FIN_M2_ALTA:
    ENT
    ASSERT FIN_M2_ALTA <= TRASPUESTA
    ASSERT M2_ALTA >= FIN_M2_TRABAJO
