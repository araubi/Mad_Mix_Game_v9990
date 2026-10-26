; ==============================================================
;  v9990_ext.asm -- Mad Mix Game v9990: el V9990 con los graficos
;  del remake (resto del codigo; la parte residente es v9990.asm)
;
;  Va en la RAM baja $0100-$0FFF, que el cargador rellena despues de
;  limpiarla. Con el V9990 el motor de actores ya no usa $0500 (los
;  actores son sprites), asi que nada lo pisa.
;
;  VRAM del V9990 (modo P1). Los generadores de patrones son mapas
;  de 256 px de ancho a 4 bpp (128 bytes por linea; el patron n esta
;  en x = (n mod 32)*8, y = (n div 32)*8):
;
;    $00000-$05FFF  capa A, patrones 0-767: espejo de la pantalla del
;                   TMS (la celda (fila r, columna c) es el patron
;                   r*32 + c)
;    $06000-$07FFF  capa A, patrones 768-1023: 768 transparente, 769
;                   negro, cifras (800+d arriba, 832+d abajo), letras
;                   (864+i, 896+i) e icono de vida (928, 929, 960, 961)
;    $08000-$0EBFF  capa A, patrones 1024-1887: el marco (27 filas)
;    $10000-$16A00  capa A, patrones 2048-2911: la portada
;    $18000-$1D7FF  patrones de los sprites (R#25 = 6)
;    $20000-$2EFFF  un bloque de 4 KB por nivel (tools/graficos.py):
;                   celdas, paleta y losetas de respaldo
;    $3FE00-$3FFFF  atributos de los sprites
;    $40000-...     capa B: losetas del laberinto, la t en x =
;                   (t mod 16)*16, y = (t div 16)*16 (patrones p, p+1,
;                   p+32 y p+33, con p = (t div 16)*64 + (t mod 16)*2)
;    $7C000         nombres de la capa A (64 x 64 entradas de 2 bytes)
;    $7E000         nombres de la capa B: la loseta (r,c) de la matriz
;                   en $7E000 + r*256 + c*4
;
;  Paleta: 0-15 los colores del TMS9918 (espejo), 16-31 el laberinto
;  del nivel, 32-47 los sprites, 48-63 el marco o la portada.
;
;  La pantalla del TMS (256x192) se ve en el V9990 (256x212) 8 lineas
;  mas abajo, asi que la ventana del laberinto queda en (32,24).
; ==============================================================

V9_VENTANA_X    EQU 32
V9_VENTANA_Y    EQU 24
V9_OX           EQU 0           ; esquina de la ventana = camara*4 + (V9_OX, V9_OY)
V9_OY           EQU 0
V9_MAX_SPRITES  EQU 48          ; entradas de V9_SPR_BUF (10 actores x 4 como mucho)
V9_NIVELES_VRAM EQU $20000
V9_PAT_TRANSP   EQU 768
V9_PAT_NEGRO    EQU 769
V9_PAT_CIFRAS   EQU 800
V9_PAT_LETRAS   EQU 864
V9_PAT_VIDA     EQU 928
V9_PAT_MARCO    EQU 1024

    ORG $0100
; Tabla de 4 bytes para convertir 2 pixeles del TMS (debe empezar en
; un limite de 256 bytes: se indexa solo con el byte bajo).
V9_T4:          DS 4

; --------------------------------------------------------------
;  Rutinas de acceso. Todas con interrupciones cerradas.
; --------------------------------------------------------------
; R#(B) = A
V9_ESCRIBIR_REG:
    PUSH AF
    LD A, B
    OUT (V9_REG_SEL), A
    POP AF
    OUT (V9_REG_DATO), A
    RET

; Puntero de escritura de VRAM = A:HL (A = bits 16-18).
V9_DIRECCION:
    PUSH AF
    XOR A
    OUT (V9_REG_SEL), A         ; R#0, con autoincremento
    LD A, L
    OUT (V9_REG_DATO), A
    LD A, H
    OUT (V9_REG_DATO), A
    POP AF
    OUT (V9_REG_DATO), A
    RET

; Puntero de lectura de VRAM = A:HL.
V9_DIRECCION_LECTURA:
    PUSH AF
    LD A, 3
    OUT (V9_REG_SEL), A         ; R#3
    LD A, L
    OUT (V9_REG_DATO), A
    LD A, H
    OUT (V9_REG_DATO), A
    POP AF
    OUT (V9_REG_DATO), A
    RET

; Paleta: C entradas desde la A, con los colores en (HL), 3 bytes cada uno.
V9_CARGAR_PALETA:
    ADD A, A
    ADD A, A
    LD B, 14
    CALL V9_ESCRIBIR_REG
    LD A, C
    ADD A, A
    ADD A, C
    LD B, A
    LD C, V9_PALETA
    OTIR
    RET

; Entradas 16-31 (laberinto) en negro: la capa B no se ve.
V9_CAPA_B_NEGRA:
    LD B, 14
    LD A, 16 * 4
    CALL V9_ESCRIBIR_REG
    LD B, 48
    XOR A
.BUCLE:
    OUT (V9_PALETA), A
    DJNZ .BUCLE
    RET

; --------------------------------------------------------------
;  V9_INICIAR: lo llama el cargador con interrupciones cerradas, con
;  el juego ya en RAM, TIC_FRAMES fijado y los graficos ya subidos a
;  la VRAM. Si no hay V9990 no hace nada (V9_PRESENTE = 0).
; --------------------------------------------------------------
V9_INICIAR:
    ; --- deteccion: R#15 (color de fondo) se puede leer y escribir ---
    LD B, 15
    LD A, $2A
    CALL V9_ESCRIBIR_REG
    LD A, $4F                   ; R#15, lectura sin autoincremento
    OUT (V9_REG_SEL), A
    IN A, (V9_REG_DATO)
    CP $2A
    RET NZ
    LD A, 15
    OUT (V9_REG_SEL), A
    LD A, $15
    OUT (V9_REG_DATO), A
    LD A, $4F
    OUT (V9_REG_SEL), A
    IN A, (V9_REG_DATO)
    CP $15
    RET NZ

    ; --- registros del modo P1 (sin reiniciar: la VRAM ya tiene los graficos) ---
    LD HL, V9_TABLA_REGISTROS
.REGISTROS:
    LD B, (HL)
    INC HL
    BIT 7, B
    JR NZ, .FIN_REGISTROS
    LD A, (HL)
    INC HL
    CALL V9_ESCRIBIR_REG
    JR .REGISTROS
.FIN_REGISTROS:
    LD A, (TIC_FRAMES)
    CP 5
    LD A, 0
    JR NZ, .NTSC
    LD A, $08                   ; PAL (50 Hz), como la maquina
.NTSC:
    LD B, 7
    CALL V9_ESCRIBIR_REG

    ; --- paletas fijas: TMS (0-15) y sprites (32-47); laberinto en negro ---
    XOR A
    LD C, 16
    LD HL, V9_PALETA_TMS
    CALL V9_CARGAR_PALETA
    LD A, 32
    LD C, 16
    LD HL, V9_PALETA_SPRITES
    CALL V9_CARGAR_PALETA
    CALL V9_CAPA_B_NEGRA

    ; --- capa B: nombres a 0 ---
    LD HL, $E000
    LD A, $07
    CALL V9_DIRECCION           ; $7E000
    LD BC, 8192
.NOMBRES_B:
    XOR A
    OUT (V9_VRAM), A
    DEC BC
    LD A, B
    OR C
    JR NZ, .NOMBRES_B

    ; --- sprites ocultos ---
    CALL V9_OCULTAR_SPRITES
    CALL V9_FIN_PANTALLA

    LD A, 1
    LD (V9_PRESENTE), A
    CALL V9_FANTASMAS_BLANCOS   ; pepsi.asm
    LD A, MODO_ESPEJO
    CALL V9_PONER_MODO
    DI
    LD B, 9
    LD A, $01                   ; IEV: interrupcion de fin de pantalla
    JP V9_ESCRIBIR_REG

; Registros del modo P1 (numero, valor), terminada en $FF.
V9_TABLA_REGISTROS:
    DB 6, $05                   ; P1, imagen de 512 px, 4 bpp
    DB 8, $42                   ; pantalla apagada (V9_PONER_MODO la enciende), sin sprites, 512 KB
    DB 13, $04                  ; paleta: capa A 0-15, capa B 16-31
    DB 15, 0                    ; color de fondo = entrada 0
    DB 16, 0                    ; ajuste de pantalla
    DB 17, 0, 18, 0, 19, 0, 20, 0   ; scroll de la capa A
    DB 21, 0, 22, 0, 23, 0, 24, 0   ; scroll de la capa B
    DB 25, $06                  ; patrones de sprites en $18000
    DB 27, 0, 28, 0             ; sin prioridad por zonas
    DB $FF

; Colores del TMS9918 en 5 bits por componente (R, G, B). El 9 (rojo
; claro) algo mas rojo: es tambien la mascota de Pepsi con la bola de
; poder (V9_META_ELEGIR).
V9_PALETA_TMS:
    DB  0,  0,  0,   0,  0,  0,   4, 25,  8,  11, 27, 15
    DB 10, 10, 29,  15, 14, 31,  26, 10,  9,   8, 29, 30
    DB 31, 10, 10,  31,  8,  6,  26, 24, 10,  28, 25, 16
    DB  4, 22,  7,  25, 11, 23,  25, 25, 25,  31, 31, 31

; --------------------------------------------------------------
;  V9_PONER_MODO: A = MODO_ESPEJO, MODO_JUEGO o MODO_PORTADA. Prepara
;  la capa A, la paleta y los sprites del modo. Vuelve con
;  interrupciones abiertas.
; --------------------------------------------------------------
V9_PONER_MODO:
    DI
    PUSH HL
    PUSH DE
    PUSH BC
    CALL V9_PORTADA_SALIR       ; v9_portada.asm: vuelta al modo P1
    LD (V9_MODO), A
    CALL V9_CAPA_B_NEGRA
    CALL V9_OCULTAR_SPRITES
    XOR A
    LD (V9_N_ACTORES), A
    LD HL, V9_OVERLAY
    LD (HL), A
    INC HL
    LD (HL), A
    INC HL
    LD (HL), A
    LD A, (V9_MODO)
    CP MODO_JUEGO
    JR Z, .JUEGO
    CP MODO_PORTADA
    JR Z, .PORTADA
    ; --- espejo: paleta del TMS, sprites apagados, todas las filas por copiar ---
    LD B, 13
    LD A, $04
    IFDEF VOLUMEN
    CALL V9_VOL_ESPEJO          ; volumen.asm: repone la paleta 0-15 del TMS
    ELSE
    CALL V9_ESCRIBIR_REG
    ENDIF
    LD B, 8
    LD A, $C2
    CALL V9_ESCRIBIR_REG
    LD DE, -32                  ; fila 1 = patrones 0-31
    CALL V9_NOMBRES_A
    CALL V9_ESPEJO_OCULTAR      ; v9_portada.asm: se ve cuando esta entero
    LD HL, V9_ESP_VALIDA
    LD B, 24
.INVALIDAR:
    LD (HL), 0
    INC HL
    DJNZ .INVALIDAR
    JR .FIN
.PORTADA:
    XOR A
    LD (V9_SPR_LISTOS), A       ; en modo bitmap no se sube la tabla de sprites
    CALL V9_PORTADA_ENTRAR      ; v9_portada.asm: modo bitmap
    JR .FIN
.JUEGO:
    LD A, 48
    LD C, 16
    LD HL, V9_PALETA_MARCO
    IFDEF VOLUMEN
    CALL V9_VOL_JUEGO           ; volumen.asm: tambien la paleta 0-15 de los sprites sombreados
    ELSE
    CALL V9_CARGAR_PALETA
    ENDIF
    LD B, 13
    LD A, $07
    CALL V9_ESCRIBIR_REG
    LD B, 8
    LD A, $82                   ; sprites encendidos
    CALL V9_ESCRIBIR_REG
    LD DE, V9_PAT_MARCO
    CALL V9_NOMBRES_A
    LD A, $FF
    LD (V9_VIDAS_PINTADAS), A
    LD A, 1
    LD (V9_MARCADOR_SUCIO), A
.FIN:
    POP BC
    POP DE
    POP HL
    EI
    RET

; Nombres de la capa A, filas 0-26: la entrada (R, C) = DE + R*32 + C.
; En el modo espejo las filas 0, 25 y 26 son negras.
V9_NOMBRES_A:
    LD HL, $C000                ; $7C000
    LD B, 27
.FILA:
    PUSH BC
    PUSH HL
    LD A, $07
    CALL V9_DIRECCION
    LD A, (V9_MODO)
    AND A
    JR Z, .NEGRA                ; espejo: cada fila aparece al copiarla (V9_PASO)
.NORMAL:
    LD B, 32
.CELDA:
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    INC DE
    DJNZ .CELDA
    JR .SIGUIENTE
.NEGRA:
    LD B, 32
.CELDA_NEGRA:
    LD A, LOW V9_PAT_NEGRO
    OUT (V9_VRAM), A
    LD A, HIGH V9_PAT_NEGRO
    OUT (V9_VRAM), A
    DJNZ .CELDA_NEGRA
    LD HL, 32
    ADD HL, DE
    EX DE, HL
.SIGUIENTE:
    POP HL
    LD BC, 128
    ADD HL, BC
    POP BC
    DJNZ .FILA
    RET

; --------------------------------------------------------------
;  Sprites: V9_SPR_BUF es la copia de la tabla de atributos que
;  V9_FIN_PANTALLA sube en el fin de pantalla del V9990.
; --------------------------------------------------------------
V9_OCULTAR_SPRITES:
    LD HL, V9_SPR_BUF + 3
    LD DE, 4
    LD B, V9_MAX_SPRITES
.BUCLE:
    LD (HL), $10                ; SD: no se ve
    ADD HL, DE
    DJNZ .BUCLE
    LD A, 1
    LD (V9_SPR_LISTOS), A
    RET

; Desde V9_ISR, con el fin de pantalla del V9990: scroll de la capa B
; y, si hay, la tabla de sprites nueva. Usa AF, BC y HL.
V9_FIN_PANTALLA:
    ; con la imagen ya empezada no se toca el scroll: el V9990 recoloca
    ; las lineas que quedan aunque el valor sea el mismo y la ventana da
    ; un bote (f2k; pasaba al poner READY?, con la interrupcion tarde)
    IN A, (V9_ESTADO)
    AND $40                     ; VR: fuera de la imagen
    JR Z, .SPRITES
    LD A, 21
    OUT (V9_REG_SEL), A
    LD HL, V9_SCROLL
    LD BC, 4 * 256 + V9_REG_DATO
    OTIR
.SPRITES:
    LD A, (V9_SPR_LISTOS)
    AND A
    RET Z
    XOR A
    LD (V9_SPR_LISTOS), A
    LD HL, $FE00
    LD A, $03
    CALL V9_DIRECCION           ; $3FE00
    LD HL, V9_SPR_BUF
    LD BC, V9_MAX_SPRITES * 4 * 256 + V9_VRAM
    OTIR
    RET

; --------------------------------------------------------------
;  V9_ACTOR_EXT: desde V9_ACTOR (MOTOR_ACTORES) con B = sprite,
;  E = columna, D = fila, A = indicadores. Mismos filtros que el
;  motor original; apunta el actor y vuelve sin dibujar nada.
;  Conserva todos los registros.
; --------------------------------------------------------------
V9_ACTOR_EXT:
    PUSH HL
    PUSH AF
    LD A, (V9_N_ACTORES)
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
    LD A, (V9_N_ACTORES)
    INC A
    LD (V9_N_ACTORES), A
    DEC A
    ADD A, A
    ADD A, A
    ADD A, LOW V9_ACTORES
    LD L, A
    LD A, 0
    ADC A, HIGH V9_ACTORES
    LD H, A
    LD (HL), B
    INC HL
    LD (HL), E
    INC HL
    LD (HL), D
    INC HL
    POP AF
    PUSH AF
    CALL V9_INDICADORES_ACTOR   ; pepsi.asm: indicadores y color del fantasma
.FIN:
    POP AF
    POP HL
    RET

; --------------------------------------------------------------
;  V9_CARGAR_NIVEL_EXT: al principio de CARGAR_NIVEL. Pasa al modo
;  juego y deja el laberinto en negro hasta el primer tic.
; --------------------------------------------------------------
V9_CARGAR_NIVEL_EXT:
    LD A, (V9_MODO)
    CP MODO_JUEGO
    LD A, MODO_JUEGO
    CALL NZ, V9_PONER_MODO
    DI
    CALL V9_CAPA_B_NEGRA
    CALL V9_OCULTAR_SPRITES
    EI
    LD A, 1
    LD (V9_NIVEL_NUEVO), A
    LD A, (NIVEL_ACTUAL)
    DEC A
    CP 15
    JR C, .VALIDO
    XOR A                       ; nivel 0 (no se usa): como el 1
.VALIDO:
    ADD A, A
    ADD A, A
    ADD A, A
    ADD A, A
    LD (V9_NIVEL_MEDIO), A      ; bits 8-15 del bloque del nivel en la VRAM
    JP V9_MARCADOR_TIC

; --------------------------------------------------------------
;  V9_RELLENAR_EXT: en partida, el fin de partida deja la ventana en
;  negro (RELLENAR_SOLIDO_AREA_JUEGO_BUFFER_VRAM).
; --------------------------------------------------------------
V9_RELLENAR_EXT:
    LD A, (V9_MODO)
    CP MODO_JUEGO
    RET NZ
    DI
    CALL V9_CAPA_B_NEGRA
    CALL V9_OCULTAR_SPRITES
    EI
    RET

; --------------------------------------------------------------
;  V9_TIC: en lugar del volcado al TMS, una vez por tic (desde
;  VOLCAR_TRAS_FLANCO, con todos los registros ya guardados).
; --------------------------------------------------------------
V9_TIC:
    LD A, (V9_MODO)
    CP MODO_JUEGO
    JR Z, .JUEGO
    XOR A
    LD (V9_N_ACTORES), A
    RET
.JUEGO:
    CALL V9_BORRAR_OVERLAY
    CALL V9_PARPADEO            ; v9_portada.asm
    ; --- nivel recien cargado: paleta y matriz entera ---
    LD A, (V9_NIVEL_NUEVO)
    AND A
    JR Z, .ZONA_VISIBLE
    XOR A
    LD (V9_NIVEL_NUEVO), A
    LD A, (REGISTRO_NIVEL_LOSETA_COMODIN)
    LD (V9_COMODIN), A
    LD HL, SOMBRA_MATRIZ
    LD DE, SOMBRA_MATRIZ + 1
    LD BC, 32 * FILAS_MATRIZ - 1
    LD (HL), $FF
    LDIR
    LD B, 0
    LD D, FILAS_MATRIZ
.MATRIZ_ENTERA:
    PUSH BC
    PUSH DE
    LD C, 0
    LD E, 32
    CALL V9_COMPARAR_FILA
    POP DE
    POP BC
    INC B
    DEC D
    JR NZ, .MATRIZ_ENTERA
    ; paleta del nivel: +$E80 del bloque
    DI
    LD A, (V9_NIVEL_MEDIO)
    ADD A, $0E
    LD H, A
    LD L, $80
    LD A, HIGH (V9_NIVELES_VRAM >> 8)
    CALL V9_DIRECCION_LECTURA
    LD B, 14
    LD A, 16 * 4
    CALL V9_ESCRIBIR_REG
    LD B, 48
.PALETA:
    IN A, (V9_VRAM)
    OUT (V9_PALETA), A
    DJNZ .PALETA
    EI
.ZONA_VISIBLE:
    ; --- esquina de la ventana en pixeles del laberinto ---
    LD HL, (REGISTRO_NIVEL_POSICION_COMECOCOS)
    PUSH HL
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    LD DE, V9_OX
    ADD HL, DE                  ; HL = x
    EX (SP), HL
    LD L, H
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    LD DE, V9_OY
    ADD HL, DE                  ; HL = y
    POP DE                      ; DE = x
    PUSH HL
    PUSH DE
    ; --- scroll de la capa B = esquina - posicion de la ventana ---
    LD BC, -V9_VENTANA_Y
    ADD HL, BC
    LD A, H
    AND $01
    LD B, A                     ; SCBY1
    LD C, L                     ; SCBY0
    EX DE, HL
    LD DE, -V9_VENTANA_X
    ADD HL, DE
    LD A, L
    AND $07
    LD E, A                     ; SCBX0
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    LD A, L
    AND $3F
    LD D, A                     ; SCBX1
    DI                          ; que V9_ISR no lea un valor a medias
    LD HL, V9_SCROLL
    LD (HL), C
    INC HL
    LD (HL), B
    INC HL
    LD (HL), E
    INC HL
    LD (HL), D
    EI
    ; --- losetas visibles: 10 filas x 13 columnas desde la esquina ---
    POP HL                      ; x
    CALL .DIV16
    LD C, A                     ; columna
    POP HL                      ; y
    CALL .DIV16
    LD B, A                     ; fila
    LD D, 10
.FILAS_VISIBLES:
    LD A, B
    CP FILAS_MATRIZ
    JR NC, .ROTACION
    PUSH BC
    PUSH DE
    LD E, 13
    CALL V9_COMPARAR_FILA
    POP DE
    POP BC
    INC B
    DEC D
    JR NZ, .FILAS_VISIBLES
.ROTACION:
    ; --- y 1 fila mas en rotacion, para lo que cambie fuera de la vista ---
    LD A, (V9_FILA_ROTA)
    LD B, A
    INC A
    CP FILAS_MATRIZ
    JR C, .GUARDAR_ROTA
    XOR A
.GUARDAR_ROTA:
    LD (V9_FILA_ROTA), A
    LD C, 0
    LD E, 32
    CALL V9_COMPARAR_FILA
    CALL V9_PREPARAR_SPRITES
    JP V9_MARCADOR_TIC
; A = (HL >> 4) & 31
.DIV16:
    LD A, L
    SRL H
    RRA
    SRL H
    RRA
    SRL H
    RRA
    SRL H
    RRA
    AND 31
    RET

; --------------------------------------------------------------
;  V9_COMPARAR_FILA: fila B (< 29), E columnas (1-32) desde la C,
;  dando la vuelta en la 32. Vuelca al V9990 las losetas que no
;  coinciden con la sombra y actualiza la sombra.
; --------------------------------------------------------------
V9_COMPARAR_FILA:
    LD L, B
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
    LD H, A                     ; HL = inicio de la fila en la matriz
    PUSH HL
    LD A, C
    AND 31
    LD C, A
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO
    INC H                       ; HL = fila + columna inicial
.SIN_ACARREO:
    LD A, 32
    SUB C                       ; columnas hasta el final de la fila
    CP E
    JR C, .PARTIDA
    LD A, E                     ; cabe entera
.PARTIDA:
    LD B, A
    LD A, E
    SUB B
    LD C, A                     ; C = columnas que siguen desde la 0
    CALL V9_COMPARAR_TRAMO
    POP HL
    LD A, C
    AND A
    RET Z
    LD B, A
; B losetas desde HL (matriz); la sombra esta en HL - $8000.
V9_COMPARAR_TRAMO:
    LD D, H
    RES 7, D
    LD E, L
.BUCLE:
    LD A, (DE)
    CP (HL)
    JR NZ, .DISTINTA
.SIGUIENTE:
    INC HL
    INC DE
    DJNZ .BUCLE
    RET
.DISTINTA:
    LD A, (HL)
    LD (DE), A
    PUSH BC
    PUSH DE
    PUSH HL
    PUSH AF
    LD DE, -MATRIZ_NIVEL
    ADD HL, DE                  ; desplazamiento = fila*32 + columna
    LD A, L
    AND 31
    LD C, A
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD B, H                     ; fila
    POP AF
    CALL V9_ESCRIBIR_LOSETA
    POP HL
    POP DE
    POP BC
    JR .SIGUIENTE

; --------------------------------------------------------------
;  V9_ESCRIBIR_LOSETA: el valor A de la matriz en la fila B, columna
;  C (0-31) de la capa B. La loseta sale del bloque del nivel: la del
;  dibujo del grafista si el valor es el inicial de esa celda, el
;  suelo de esa celda si es la loseta comodin (bola comida...), y si
;  no la de respaldo de ese valor. Conserva BC y DE.
; --------------------------------------------------------------
V9_ESCRIBIR_LOSETA:
    PUSH BC
    PUSH DE
    AND $7F                     ; bit 7 = "comida"
    LD E, A
    ; registro de la celda: bloque + fila*128 + columna*4
    LD A, B
    RRCA
    AND $80
    LD L, A
    LD A, C
    ADD A, A
    ADD A, A
    OR L
    LD L, A
    LD A, B
    SRL A
    LD H, A                     ; HL = fila*128 + columna*4
    LD A, (V9_NIVEL_MEDIO)
    ADD A, H
    LD H, A
    DI
    LD A, HIGH (V9_NIVELES_VRAM >> 8)
    CALL V9_DIRECCION_LECTURA
    IN A, (V9_VRAM)             ; v0
    CP E
    JR Z, .DIBUJO
    LD A, (V9_COMODIN)
    CP E
    JR Z, .SUELO
    ; respaldo: +$F00 + valor*2
    LD A, (V9_NIVEL_MEDIO)
    ADD A, $0F
    LD H, A
    LD A, E
    ADD A, A
    LD L, A
    JR NC, .SIN_ACARREO
    INC H
.SIN_ACARREO:
    LD A, HIGH (V9_NIVELES_VRAM >> 8)
    CALL V9_DIRECCION_LECTURA
    IN A, (V9_VRAM)
    LD L, A
    IN A, (V9_VRAM)
    LD H, A
    JR .LOSETA
.DIBUJO:
    IN A, (V9_VRAM)             ; t0 bajo
    LD L, A
    IN A, (V9_VRAM)             ; t1 bajo
    IN A, (V9_VRAM)             ; altos
    AND $0F
    LD H, A
    JR .LOSETA
.SUELO:
    IN A, (V9_VRAM)
    IN A, (V9_VRAM)             ; t1 bajo
    LD L, A
    IN A, (V9_VRAM)
    RRCA
    RRCA
    RRCA
    RRCA
    AND $0F
    LD H, A
.LOSETA:
    ; HL = loseta t -> p = (t div 16)*64 + (t mod 16)*2
    LD A, L
    AND $0F
    ADD A, A
    LD E, A
    LD A, L
    AND $F0
    LD L, A
    ADD HL, HL
    ADD HL, HL
    LD A, L
    OR E
    LD E, A
    LD D, H                     ; DE = p
    LD A, C
    ADD A, A
    ADD A, A
    LD L, A                     ; columna*4
    LD A, B
    ADD A, $E0
    LD H, A                     ; $E000 + fila*256 (+ $70000)
    LD A, $07
    CALL V9_DIRECCION
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    LD A, E
    INC A
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    LD A, L
    OR $80                      ; siguiente fila de nombres (+128)
    LD L, A
    LD A, $07
    CALL V9_DIRECCION
    LD A, E
    OR 32
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    LD A, E
    OR 33
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    EI
    POP DE
    POP BC
    RET

; --------------------------------------------------------------
;  V9_PREPARAR_SPRITES: actores apuntados en este tic -> V9_SPR_BUF.
;  Cada actor es 1-4 sprites de 16x16 (V9_META, de graficos.py),
;  colocados respecto a la esquina del sprite original de 24x24: la
;  columna E es x = E*2 - 32 en la ventana y la fila D es y = D (o
;  D - 256 si pasa del limite de recorte, 144 o 176 con el bit 5).
;  Los ultimos actores se dibujaban encima: van primero en la tabla.
; --------------------------------------------------------------
V9_PREPARAR_SPRITES:
    LD IY, V9_SPR_BUF
    LD A, (V9_N_ACTORES)
    AND A
    JP Z, .RESTO
    LD B, A
    XOR A
    LD (V9_N_ACTORES), A
    DEC B
    LD A, B
    ADD A, A
    ADD A, A
    LD E, A
    LD D, 0
    LD IX, V9_ACTORES
    ADD IX, DE                  ; ultimo actor
    INC B
.ACTOR:
    PUSH BC
    ; puntero a las partes: V9_META[sprite*2 + espejo]
    LD A, (IX+0)
    ADD A, A
    BIT 7, (IX+3)
    JR Z, .SIN_ESPEJO
    INC A
.SIN_ESPEJO:
    CALL V9_META_ELEGIR         ; HL -> V9_META[A] (o V9_META_PEPSI, pepsi.asm)
    LD E, (HL)
    INC HL
    LD D, (HL)                  ; DE -> n, (dx, dy, patron)...
    ; y en pantalla - 1 (el V9990 pinta el sprite desde la linea Y+1)
    LD A, (IX+3)
    AND $20
    LD A, 144
    JR Z, .LIMITE
    LD A, 176
.LIMITE:
    LD C, A
    LD A, (IX+2)
    LD L, A
    LD H, 0
    CP C
    JR C, .Y_POSITIVA
    DEC H                       ; por encima de la ventana
.Y_POSITIVA:
    LD BC, V9_VENTANA_Y - 1
    ADD HL, BC
    LD (V9_BASE_Y), HL
    ; x en pantalla = E*2 (- 32 + 32 de la ventana)
    LD L, (IX+1)
    LD H, 0
    ADD HL, HL
    LD (V9_BASE_X), HL
    LD A, (DE)
    INC DE
    AND A
    JR Z, .SIGUIENTE_ACTOR
    LD B, A
.PARTE:
    LD A, IYL
    CP LOW (V9_SPR_BUF + V9_MAX_SPRITES * 4)
    JR Z, .SIGUIENTE_ACTOR      ; tabla llena
    PUSH BC
    ; x
    LD A, (DE)
    INC DE
    LD L, A
    ADD A, A
    SBC A, A
    LD H, A                     ; HL = dx con signo
    LD BC, (V9_BASE_X)
    ADD HL, BC
    LD (IY+2), L
    LD A, H
    AND $03
.ATRIB:
    OR $A0                      ; paleta 32-47 (o 0-15, V9_META_ELEGIR), detras de la capa A
    LD (IY+3), A
    ; y
    LD A, (DE)
    INC DE
    LD L, A
    ADD A, A
    SBC A, A
    LD H, A
    LD BC, (V9_BASE_Y)
    ADD HL, BC
    LD (IY+0), L
    LD A, (DE)
    INC DE
    LD (IY+1), A
    LD BC, 4
    ADD IY, BC
    POP BC
    DJNZ .PARTE
.SIGUIENTE_ACTOR:
    LD DE, -4
    ADD IX, DE
    POP BC
    DEC B
    JP NZ, .ACTOR
.RESTO:
    ; el resto de la tabla, oculto
    LD A, IYL
    CP LOW (V9_SPR_BUF + V9_MAX_SPRITES * 4)
    JR Z, .LISTO
    LD (IY+3), $10
    LD DE, 4
    ADD IY, DE
    JR .RESTO
.LISTO:
    DI
    LD A, 1
    LD (V9_SPR_LISTOS), A
    EI
    RET

V9_BASE_X: DW 0
V9_BASE_Y: DW 0

; --------------------------------------------------------------
;  V9_MARCADOR_TIC: vidas y marcador en la capa A, si han cambiado.
;  Vidas: iconos de 16x16 en las columnas 9 + 3*i de la fila 23;
;  marcador: 6 caracteres de 8x16 desde la columna 22.
; --------------------------------------------------------------
V9_MARCADOR_TIC:
    LD A, (VIDAS_RESTANTES)
    LD HL, V9_VIDAS_PINTADAS
    CP (HL)
    JR Z, .PUNTOS
    LD (HL), A
    LD C, A                     ; vidas
    LD B, 0                     ; i
.VIDA:
    LD A, B
    ADD A, A
    ADD A, B
    ADD A, 9
    LD L, A                     ; columna
    LD DE, V9_PAT_VIDA
    LD A, B
    CP C
    JR C, .CON_VIDA
    LD DE, V9_PAT_NEGRO
.CON_VIDA:
    PUSH BC
    LD H, 23
    CALL V9_NOMBRE_A_2X2
    POP BC
    INC B
    LD A, B
    CP 5
    JR NZ, .VIDA
    LD A, 1
    LD (V9_MARCADOR_SUCIO), A   ; el quinto icono pisa el marcador
.PUNTOS:
    LD A, (V9_MARCADOR_SUCIO)
    AND A
    RET Z
    XOR A
    LD (V9_MARCADOR_SUCIO), A
    LD IX, (V9_TEXTO_PUNTOS)
    LD A, IXH
    OR IXL
    RET Z
    LD L, 22
    LD B, 6
.CARACTER:
    LD A, (IX+0)
    CP $FF
    RET Z
    INC IX
    SUB "0"
    CP 10
    JR NC, .LETRA
    ADD A, LOW V9_PAT_CIFRAS
    LD E, A
    LD D, HIGH V9_PAT_CIFRAS
    JR .PINTAR
.LETRA:
    SUB "A" - "0"
    CP 26
    JR NC, .ESPACIO
    ADD A, LOW V9_PAT_LETRAS
    LD E, A
    LD D, HIGH V9_PAT_LETRAS
.PINTAR:
    ; arriba DE, abajo DE + 32
    PUSH BC
    PUSH HL
    LD H, 23
    CALL V9_DIRECCION_NOMBRE_A
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    POP HL
    PUSH HL
    LD H, 24
    CALL V9_DIRECCION_NOMBRE_A
    LD A, E
    ADD A, 32
    OUT (V9_VRAM), A
    LD A, D
    ADC A, 0
    OUT (V9_VRAM), A
    EI
    POP HL
    POP BC
    JR .OTRO
.ESPACIO:
    PUSH BC
    PUSH HL
    LD DE, V9_PAT_NEGRO
    LD H, 23
    CALL V9_DIRECCION_NOMBRE_A
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    POP HL
    PUSH HL
    LD H, 24
    CALL V9_DIRECCION_NOMBRE_A
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    EI
    POP HL
    POP BC
.OTRO:
    INC L
    DJNZ .CARACTER
    RET

; Puntero de escritura en el nombre (fila H, columna L) de la capa A.
; Cierra las interrupciones (quien llama las abre al acabar).
V9_DIRECCION_NOMBRE_A:
    DI
    PUSH HL
    LD A, L
    ADD A, A
    LD L, H
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL                  ; fila*128
    OR L
    LD L, A
    LD A, H
    OR $C0
    LD H, A                     ; $7C000 + fila*128 + columna*2
    LD A, $07
    CALL V9_DIRECCION
    POP HL
    RET

; Bloque de 2x2 nombres en (fila H, columna L): DE, DE+1 / DE+32, DE+33,
; o los cuatro negros si DE = V9_PAT_NEGRO.
V9_NOMBRE_A_2X2:
    LD BC, 1 * 256 + 32
    LD A, E
    CP LOW V9_PAT_NEGRO
    JR NZ, .DIBUJO
    LD BC, 0
.DIBUJO:
    CALL V9_DIRECCION_NOMBRE_A
    CALL .DOS
    INC H
    CALL V9_DIRECCION_NOMBRE_A
    LD A, E
    ADD A, C
    LD E, A
    CALL .DOS
    EI
    RET
.DOS:
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    LD A, E
    ADD A, B
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    RET

; --------------------------------------------------------------
;  Espejo de la pantalla del TMS9918 (SCREEN 2: la celda (r, c),
;  linea l esta en r*256 + c*8 + l de la tabla de patrones y en
;  $2000 + lo mismo de la de color).
;
;  V9_LEER_FILA: copia la fila de caracteres A del TMS a
;  V9_BUF_PATRONES / V9_BUF_COLORES y devuelve en HL una suma de
;  comprobacion (tipo Fletcher de 8 bits) para saber si ha cambiado.
; --------------------------------------------------------------
V9_LEER_FILA:
    PUSH AF
    LD H, A
    LD L, 0
    LD DE, V9_BUF_PATRONES
    CALL .TRAMO
    POP AF
    PUSH HL
    ADD A, $20
    LD H, A
    LD L, 0
    LD DE, V9_BUF_COLORES
    CALL .TRAMO
    POP DE
    ADD HL, DE
    RET
.TRAMO:
    DI
    LD A, L
    OUT ($99), A
    LD A, H
    AND $3F
    OUT ($99), A                ; lectura
    LD HL, 0
    LD B, L
    EX (SP), HL                 ; tiempo para que el TMS lea el primer byte
    EX (SP), HL
.BYTE:
    IN A, ($98)
    LD (DE), A
    INC DE
    ADD A, L
    LD L, A
    LD A, H
    RLCA                        ; f2j: sin girar, cambiar el color de 8*k
    ADD A, L                    ; bytes en $60 (2 JOYSTICK) no se notaba
    LD H, A
    DJNZ .BYTE
    EI
    RET

; V9_CONVERTIR_CELDAS: fila A, celdas C (columna inicial) a C+B-1, de
; los buferes a los patrones del espejo (r*32 + c) en el generador de
; la capa A, con los colores del TMS pasados por V9_MAPA (16 bytes).
V9_CONVERTIR_CELDAS:
    LD (.FILA), A
    LD A, B
    LD (.N), A
    LD A, C
    LD (.C0), A
    LD A, $FF
    LD (.ULTIMO), A             ; color ya en V9_T4 (ninguno)
    XOR A
.LINEA:
    LD (.L), A
    ; direccion = fila*1024 + linea*128 + c0*4
    RRCA
    AND $80
    LD L, A
    LD A, (.C0)
    ADD A, A
    ADD A, A
    OR L
    LD L, A                     ; (linea and 1)*128 + c0*4
    LD A, (.L)
    SRL A
    LD H, A
    LD A, (.FILA)
    ADD A, A
    ADD A, A
    OR H
    LD H, A                     ; fila*4 + linea/2
    DI
    XOR A
    CALL V9_DIRECCION
    ; HL -> buffer de patrones, celda c0, linea l
    LD A, (.C0)
    ADD A, A
    ADD A, A
    ADD A, A
    LD L, A
    LD A, (.L)
    OR L
    LD L, A
    LD H, HIGH V9_BUF_PATRONES
    LD A, (.ULTIMO)
    LD E, A
    LD A, (.N)
    LD D, A                     ; celdas
    CALL V9_CELDAS              ; pepsi.asm (zona $8347)
    EI
    LD A, E
    LD (.ULTIMO), A
    LD A, (.L)
    INC A
    CP 8
    JP NZ, .LINEA
    RET
; color A (tinta arriba, fondo abajo) -> V9_T4; E = A
.TABLA:
    LD E, A
    PUSH HL
    PUSH DE
    LD HL, (V9_MAPA)
    PUSH HL
    AND $0F
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO_1
    INC H
.SIN_ACARREO_1:
    LD D, (HL)                  ; fondo
    POP HL
    LD A, E
    RRCA
    RRCA
    RRCA
    RRCA
    AND $0F
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO_2
    INC H
.SIN_ACARREO_2:
    LD E, (HL)                  ; tinta
    LD HL, V9_T4
    LD A, D
    RLCA
    RLCA
    RLCA
    RLCA
    LD C, A                     ; fondo << 4
    OR D
    LD (HL), A                  ; 00
    INC L
    LD A, C
    OR E
    LD (HL), A                  ; 01
    INC L
    LD A, E
    RLCA
    RLCA
    RLCA
    RLCA
    LD B, A                     ; tinta << 4
    OR D
    LD (HL), A                  ; 10
    INC L
    LD A, B
    OR E
    LD (HL), A                  ; 11
    POP DE
    POP HL
    RET
.FILA:   DB 0
.N:      DB 0
.C0:     DB 0
.L:      DB 0
.ULTIMO: DB 0

; --------------------------------------------------------------
;  V9_PASO_ESPEJO: en el modo espejo, una fila del TMS por frame: si
;  ha cambiado desde la ultima vez, se copia a la capa A. Con 24
;  filas, toda la pantalla se repasa cada 24 frames. Lo llaman las
;  esperas de tecla (V9_PULSACION, V9_TEXTO) y la ISR cuando el juego
;  esta en un HALT (V9_PASO_ESPEJO_ISR).
; --------------------------------------------------------------
V9_PASO_ESPEJO:
    LD A, (V9_MODO)
    CP MODO_ESPEJO
    RET NZ
    PUSH HL                     ; HL se conserva siempre (ESPERAR_TECLA_NUEVA
                                ; tiene en HL el puntero de la tabla de teclas)
    LD A, (CONTADOR_FRAMES)
    LD HL, V9_ULTIMO_PASO
    CP (HL)
    LD (HL), A
    CALL Z, V9_FILA_PENDIENTE   ; pepsi.asm: una fila sin copiar no espera al frame
    JR Z, .FIN
    PUSH DE
    PUSH BC
    PUSH IX
    CALL V9_PASO
    POP IX
    POP BC
    POP DE
.FIN:
    POP HL
    RET

V9_PASO_ESPEJO_ISR:
    LD A, (V9_MODO)
    CP MODO_ESPEJO
    RET NZ
    PUSH DE
    PUSH IX
    CALL V9_PASO
    DI                          ; seguimos dentro de la ISR
    POP IX
    POP DE
    RET

V9_PASO:
    LD A, (V9_ESP_FILA)
    LD C, A
    INC A
    CP 24
    JR C, .GUARDAR
    XOR A
.GUARDAR:
    LD (V9_ESP_FILA), A
    LD A, C
    PUSH BC
    CALL V9_LEER_FILA
    POP BC
    ; comparar con la suma anterior
    LD B, 0
    LD IX, V9_ESP_SUMAS
    ADD IX, BC
    ADD IX, BC
    PUSH HL
    LD HL, V9_ESP_VALIDA
    ADD HL, BC
    LD A, (HL)
    LD (HL), 1
    POP HL
    AND A
    JR Z, .COPIAR
    LD A, (IX+0)
    CP L
    JR NZ, .COPIAR
    LD A, (IX+1)
    CP H
    RET Z
.COPIAR:
    LD (IX+0), L
    LD (IX+1), H
    LD HL, V9_MAPA_TMS
    LD (V9_MAPA), HL
    LD A, C
    JP V9_FILA_A_CAPA           ; v9_portada.asm

V9_MAPA_TMS:
    DB 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

; --------------------------------------------------------------
;  V9_TEXTO_EXT: despues de DIBUJAR_TEXTO_VRAM (HL = direccion del
;  texto en el TMS, DE = el registro del texto). En partida, los
;  textos sobre la ventana (FASE, READY?, ESTAS FRITO...) se copian a
;  la capa A y se borran en el tic siguiente, igual que en el TMS los
;  tapa el volcado siguiente. En el modo espejo es un buen momento
;  para un paso del espejo.
; --------------------------------------------------------------
V9_TEXTO_EXT:
    LD A, (V9_MODO)
    CP MODO_JUEGO
    JP NZ, V9_PASO_ESPEJO
    LD A, H
    CP 2
    RET C
    CP 20
    RET NC                      ; fuera de las filas 2-19 de la ventana
    LD (.FILA), A
    LD A, L
    RRCA
    RRCA
    RRCA
    AND 31
    LD C, A                     ; columna inicial
    ; ancho: un caracter por entrada, o los que salta un codigo < $20
    LD A, (DE)
    LD B, A
    INC DE
    INC DE
    LD L, 0
.ANCHO:
    LD A, (DE)
    INC DE
    CP $20
    JR NC, .UNO
    ADD A, L
    LD L, A
    JR .SIGUE
.UNO:
    INC L
.SIGUE:
    DJNZ .ANCHO
    ; recorte a las columnas 4-27
    LD A, C
    CP 4
    JR NC, .IZQUIERDA_BIEN
    LD A, C
    SUB 4
    ADD A, L
    LD L, A
    LD C, 4
.IZQUIERDA_BIEN:
    LD A, C
    ADD A, L
    CP 29
    JR C, .DERECHA_BIEN
    LD A, 28
    SUB C
    LD L, A
.DERECHA_BIEN:
    LD A, L
    AND A
    RET Z
    CP 25
    RET NC
    LD B, L
    PUSH BC
    LD A, (.FILA)
    CALL V9_LEER_FILA
    POP BC
    PUSH BC
    LD HL, V9_TMS_A_MARCO
    LD (V9_MAPA), HL
    LD A, (.FILA)
    CALL V9_CONVERTIR_CELDAS
    POP BC
    ; nombres (fila + 1, c) -> patron fila*32 + c
    LD A, (.FILA)
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD E, C
    LD D, 0
    ADD HL, DE
    EX DE, HL                   ; DE = primer patron
    LD A, (.FILA)
    INC A
    LD H, A
    LD L, C
    CALL V9_DIRECCION_NOMBRE_A
.NOMBRE:
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    INC DE
    DJNZ .NOMBRE
    EI
    ; fila en la mascara de V9_OVERLAY
    LD A, (.FILA)
    LD C, A
    SRL A
    SRL A
    SRL A
    LD E, A
    LD D, 0
    LD HL, V9_OVERLAY
    ADD HL, DE
    LD A, C
    AND 7
    LD B, A
    LD A, 1
    JR Z, .MARCAR
.DESPLAZAR:
    ADD A, A
    DJNZ .DESPLAZAR
.MARCAR:
    OR (HL)
    LD (HL), A
    RET
.FILA: DB 0

; Filas de la ventana con texto copiado: vuelven al marco (transparente).
V9_BORRAR_OVERLAY:
    LD C, 0                     ; fila
    LD HL, V9_OVERLAY
.BYTE:
    LD A, (HL)
    LD (HL), 0
    LD B, 8
.BIT:
    RRCA
    JR NC, .SIGUIENTE
    PUSH AF
    PUSH BC
    PUSH HL
    ; nombres (C+1, 4..27) = V9_PAT_MARCO + (C+1)*32 + columna
    LD A, C
    INC A
    LD H, A
    LD L, 4
    LD E, A
    LD D, 0
    EX DE, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    LD BC, V9_PAT_MARCO + 4
    ADD HL, BC
    EX DE, HL                   ; DE = patron de la columna 4
    CALL V9_DIRECCION_NOMBRE_A
    LD B, 24
.NOMBRE:
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    INC DE
    DJNZ .NOMBRE
    EI
    POP HL
    POP BC
    POP AF
.SIGUIENTE:
    INC C
    DJNZ .BIT
    INC HL
    LD A, L
    CP LOW (V9_OVERLAY + 3)
    JR NZ, .BYTE
    RET

; --------------------------------------------------------------
;  Datos de tools/graficos.py: paletas del marco, la portada y los
;  sprites, colores del TMS en la paleta del marco y la tabla de
;  sprites de cada actor (V9_META).
; --------------------------------------------------------------
    INCLUDE "../../build/v9_datos.inc"

; Z si la fila que toca ya esta copiada (entonces se espera al frame
; siguiente); NZ si esta pendiente (pantalla recien limpiada).
V9_FILA_PENDIENTE:
    PUSH HL
    PUSH DE
    LD HL, (V9_ESP_FILA)
    LD H, 0
    LD DE, V9_ESP_VALIDA
    ADD HL, DE
    LD A, (HL)
    POP DE
    POP HL
    CP 1
    RET
; --------------------------------------------------------------
;  Variables
; --------------------------------------------------------------
V9_N_ACTORES:      DB 0
V9_ACTORES:        DS 10 * 4    ; sprite, columna, fila, indicadores
V9_NIVEL_NUEVO:    DB 0
V9_NIVEL_MEDIO:    DB 0
V9_COMODIN:        DB 0
V9_FILA_ROTA:      DB 0
V9_VIDAS_PINTADAS: DB $FF
V9_OVERLAY:        DS 3         ; filas 0-23 con texto copiado sobre la ventana
V9_MAPA:           DW V9_MAPA_TMS
V9_ESP_FILA:       DB 0
V9_ESP_VALIDA:     DS 24
V9_ESP_SUMAS:      DS 48
    IF HIGH $ != HIGH ($ + V9_MAX_SPRITES * 4)
    ALIGN 256                   ; V9_SPR_BUF no cruza un limite de pagina
    ENDIF
V9_SPR_BUF:        DS V9_MAX_SPRITES * 4
    ASSERT HIGH V9_SPR_BUF == HIGH (V9_SPR_BUF + V9_MAX_SPRITES * 4)
; V9_META_ELEGIR (.NO_FANTASMA): DE = V9_META y, en la fase amarilla del
; parpadeo, el comecocos rojo con sus dibujos amarillos (y la mascota de
; The Pepsi Challenge sin la paleta roja).
V9_PAC_AMARILLO:
    LD DE, V9_META
    LD A, (V9_AMARILLO)
    AND A
    RET Z
    INC SP
    INC SP                      ; ya no vuelve a V9_META_ELEGIR
    LD A, (MODO_PEPSI)
    AND A
    JP NZ, V9_META_ELEGIR.PEPSI_MAPA
    PUSH BC
    LD A, L
    AND $FE
    LD C, A
    PUSH HL
    LD HL, .TABLA
    LD B, 6
.BUSCAR:
    LD A, (HL)
    INC HL
    CP C
    JR Z, .CAMBIO
    INC HL
    DJNZ .BUSCAR
    POP HL
    JR .INDICE
.CAMBIO:
    LD A, (HL)
    POP HL
    XOR C
    XOR L                       ; el amarillo, con el mismo espejo
    LD L, A
.INDICE:
    POP BC
    ADD HL, HL
    ADD HL, DE
    RET
.TABLA:                         ; rojo -> amarillo (sprite * 2)
    DB 7 * 2, 0 * 2, 8 * 2, 1 * 2, 9 * 2, 2 * 2
    DB 10 * 2, 3 * 2, 57 * 2, 4 * 2, 11 * 2, 5 * 2

FIN_V9990_EXT:
    ASSERT FIN_V9990_EXT <= MODO_PEPSI     ; pepsi.asm, $0F00

; Buferes de una fila de caracteres del TMS, en la zona libre de detras
; de volcado_haz.asm (no se cargan).
V9_BUF_PATRONES    EQU $7700
V9_BUF_COLORES     EQU V9_BUF_PATRONES + 256
    ASSERT FIN_VOLCADO_HAZ <= V9_BUF_PATRONES
    ASSERT V9_BUF_COLORES + 256 <= SOMBRA_MATRIZ
