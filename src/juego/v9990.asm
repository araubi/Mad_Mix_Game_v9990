; ==============================================================
;  v9990.asm -- Mad Mix Game v9990, fase F1: laberinto en el V9990
;
;  Codigo nuevo en la zona libre $6C00-$83FF. Con un cartucho
;  GFX9000 (V9990) presente, el laberinto se dibuja en la capa B del
;  modo P1 (256x212, patrones de 8x8 a 4 bpp) y se desplaza con los
;  registros de scroll por hardware, siguiendo la camara del juego.
;  La pantalla del TMS9918 sigue funcionando igual, para comparar las
;  dos salidas (en openMSX: set videosource GFX9000 / MSX).
;
;  - Losetas: las 91 losetas de 16x16 a 1 bpp (GRAFICOS_LOSETAS) se
;    convierten al arrancar a 4 patrones de 8x8 cada una, en un mapa
;    de 256 px de ancho en el generador de la capa B ($40000): la
;    loseta t ocupa x = (t mod 16)*16, y = (t div 16)*16. Los pixeles
;    a 0 valen 1 y los pixeles a 1 valen 2; con el desplazamiento de
;    paleta de la capa B (16) son las entradas 17 (fondo) y 18
;    (tinta), que se cargan con los colores del TMS del nivel actual.
;  - Laberinto: la matriz del nivel ($FC50, 32 x 29 losetas) se
;    copia entera a la tabla de nombres de la capa B ($7E000, 64 x 64
;    entradas = 512 x 512 px, sitio de sobra). La loseta (fila r,
;    columna c) va en $7E000 + r*256 + c*4. Una copia sombra de la
;    matriz indica que losetas han cambiado: en cada tic se comparan
;    las de la zona visible mas 1 fila en rotacion, y la matriz
;    entera al cargar un nivel.
;  - Scroll: los registros de la capa B se calculan en cada tic a
;    partir de REGISTRO_NIVEL_POSICION_COMECOCOS y se escriben en la
;    interrupcion de fin de pantalla del propio V9990 (V9_ISR): si
;    se escribe el scroll vertical con la imagen en curso, el V9990
;    parte la pantalla por esa linea.
;  - Capa A (delante): de momento solo una mascara negra fuera de la
;    ventana de juego (24 x 18 caracteres en (32,24)); el marco de
;    caramelo y el marcador llegaran en la fase F3.
;
;  Parches en el juego original (mismo tamano, ninguna etiqueta se
;  mueve): el vector de $0038 apunta a V9_ISR (ACTIVAR_INTERRUPCION_
;  MODO_1) y CARGAR_NIVEL empieza llamando a V9_CARGAR_NIVEL. Ademas,
;  WAIT_VBLANK_OPT (optimizaciones.asm) llama a V9_TIC y el cargador
;  de la ROM a V9_INICIAR. Sin GFX9000 el juego es identico a f0c.
;
;  Puertos del V9990: $60 VRAM, $61 paleta, $63 dato de registro,
;  $64 seleccion de registro, $66 indicadores de interrupcion,
;  $67 control del sistema.
; ==============================================================

V9_VRAM     EQU $60
V9_PALETA   EQU $61
V9_REG_DATO EQU $63
V9_REG_SEL  EQU $64
V9_INT_FLAG EQU $66
V9_SISTEMA  EQU $67

MATRIZ_NIVEL    EQU $FC50       ; matriz del nivel activo (32 x 29)
FILAS_MATRIZ    EQU 29
SOMBRA_MATRIZ   EQU MATRIZ_NIVEL - $8000 ; $7C50: copia de la matriz ya volcada al V9990 (928 bytes, no se carga)

; Ventana de juego en la pantalla del V9990 y su correspondencia con
; la camara. El pixel (0,0) de la ventana del TMS es el pixel
; (camara.L*4 + V9_OX, camara.H*4 + V9_OY) del laberinto (medido en
; openMSX comparando las dos salidas).
V9_VENTANA_X    EQU 32
V9_VENTANA_Y    EQU 24
V9_OX           EQU 0
V9_OY           EQU 0

    ASSERT $ <= $6C00
    ORG $6C00
V9_INICIAR_ENTRADA:
    JP V9_INICIAR               ; $6C00: lo llama el cargador de la ROM
V9_PRESENTE:    DB 0            ; 1 si hay V9990
V9_COLOR_NIVEL: DB 0            ; ultimo color de laberinto cargado en la paleta
V9_FILA_ROTA:   DB 0            ; siguiente fila de la comparacion en rotacion
V9_SCROLL:      DS 4            ; R#21-R#24 (SCBY0, SCBY1, SCBX0, SCBX1) pendientes
V9_SCROLL_NUEVO: DS 4           ; los mismos, mientras se calculan

; --------------------------------------------------------------
;  V9_ISR: delante de ENTRADA_INTERRUPCION_VBLANK (ACTIVAR_
;  INTERRUPCION_MODO_1 instala este vector). Si la interrupcion es
;  la de fin de pantalla del V9990, la atiende (escribe el scroll
;  pendiente) y vuelve; si a la vez hay una del TMS, la linea de
;  interrupcion sigue activa y se entra otra vez nada mas hacer EI.
; --------------------------------------------------------------
V9_ISR:
    PUSH AF
    LD A, (V9_PRESENTE)
    AND A
    JR Z, .TMS
    IN A, (V9_INT_FLAG)
    RRCA                        ; bit 0 = VI, fin de pantalla
    JR NC, .TMS
    LD A, 1
    OUT (V9_INT_FLAG), A        ; borra VI
    PUSH HL
    PUSH BC
    LD A, 21
    OUT (V9_REG_SEL), A
    LD HL, V9_SCROLL
    LD BC, 4 * 256 + V9_REG_DATO
    OTIR
    POP BC
    POP HL
    POP AF
    EI
    RET
.TMS:
    POP AF
    JP ENTRADA_INTERRUPCION_VBLANK

; --------------------------------------------------------------
;  V9_ESCRIBIR_REG: R#(B) = A. Con interrupciones cerradas.
; --------------------------------------------------------------
V9_ESCRIBIR_REG:
    PUSH AF
    LD A, B
    OUT (V9_REG_SEL), A
    POP AF
    OUT (V9_REG_DATO), A
    RET

; --------------------------------------------------------------
;  V9_DIRECCION: puntero de escritura de VRAM = A:HL (A = bits 16-18).
;  Con interrupciones cerradas.
; --------------------------------------------------------------
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

; --------------------------------------------------------------
;  V9_RELLENAR: escribe BC veces el byte E desde el puntero actual.
; --------------------------------------------------------------
V9_RELLENAR:
    LD A, E
    OUT (V9_VRAM), A
    DEC BC
    LD A, B
    OR C
    JR NZ, V9_RELLENAR
    RET

; --------------------------------------------------------------
;  V9_INICIAR: lo llama el cargador con interrupciones cerradas, con
;  el juego ya en RAM y TIC_FRAMES fijado. Si no hay V9990 no hace
;  nada (V9_PRESENTE = 0) y el juego sigue como en f0c.
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

    ; --- reinicio y modo P1 ---
    LD A, 2
    OUT (V9_SISTEMA), A         ; reinicio: todos los registros a 0
    XOR A
    OUT (V9_SISTEMA), A         ; MCS = 0 (reloj XTAL, el de P1)
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

    ; --- paleta: 0-15 = los colores del TMS9918 ---
    LD B, 14
    XOR A
    CALL V9_ESCRIBIR_REG
    LD HL, V9_PALETA_TMS
    LD BC, 48 * 256 + V9_PALETA
    OTIR
    LD A, $1E                   ; laberinto: tinta negra, fondo gris (se corrige al primer tic)
    CALL V9_CARGAR_COLOR_LABERINTO

    ; --- capa A: patron 0 transparente, patron 1 negro (color 1) ---
    LD HL, 0
    XOR A
    CALL V9_DIRECCION
    LD BC, 8 * 128              ; primera fila de patrones (8 lineas)
    LD E, 0
    CALL V9_RELLENAR
    LD B, 8
    LD HL, 4                    ; patron 1: x = 8 px = 4 bytes
.PATRON_NEGRO:
    PUSH BC
    XOR A
    CALL V9_DIRECCION
    LD BC, 4
    LD E, $11
    CALL V9_RELLENAR
    LD BC, 128
    ADD HL, BC
    POP BC
    DJNZ .PATRON_NEGRO

    ; --- capa A: mascara (1 fuera de la ventana, 0 dentro) ---
    LD HL, $C000
    LD A, $07
    CALL V9_DIRECCION           ; $7C000
    LD D, 0                     ; fila
.FILA_MASCARA:
    LD E, 0                     ; columna
.CELDA_MASCARA:
    LD A, D
    SUB V9_VENTANA_Y / 8
    CP 18
    JR NC, .FUERA
    LD A, E
    SUB V9_VENTANA_X / 8
    CP 24
    JR NC, .FUERA
    XOR A
    JR .ESCRIBIR_CELDA
.FUERA:
    LD A, 1
.ESCRIBIR_CELDA:
    OUT (V9_VRAM), A
    XOR A
    OUT (V9_VRAM), A
    INC E
    BIT 6, E
    JR Z, .CELDA_MASCARA
    INC D
    BIT 6, D
    JR Z, .FILA_MASCARA

    ; --- capa B: nombres a 0 y losetas convertidas ---
    LD HL, $E000
    LD A, $07
    CALL V9_DIRECCION           ; $7E000
    LD BC, 8192
    LD E, 0
    CALL V9_RELLENAR
    CALL V9_CONVERTIR_LOSETAS

    ; --- sombra de la matriz: todo distinto, para el primer volcado ---
    LD HL, SOMBRA_MATRIZ
    LD DE, SOMBRA_MATRIZ + 1
    LD BC, 32 * FILAS_MATRIZ - 1
    LD (HL), $FF
    LDIR

    LD A, 1
    LD (V9_PRESENTE), A
    LD B, 9
    LD A, $01                   ; IEV: interrupcion de fin de pantalla
    CALL V9_ESCRIBIR_REG
    LD B, 8
    LD A, $42                   ; pantalla apagada hasta el primer nivel, sin sprites (llegan en F2), 512 KB
    JP V9_ESCRIBIR_REG

; Registros del modo P1 (numero, valor), terminada en $FF.
V9_TABLA_REGISTROS:
    DB 6, $05                   ; P1, imagen de 512 px, 4 bpp
    DB 13, $04                  ; paleta: capa A 0-15, capa B 16-31
    DB 15, 0                    ; color de fondo = entrada 0
    DB 16, 0                    ; ajuste de pantalla
    DB 17, 0, 18, 0, 19, 0, 20, 0   ; scroll de la capa A
    DB 21, 0, 22, 0, 23, 0, 24, 0   ; scroll de la capa B
    DB 25, 0, 27, 0, 28, 0
    DB $FF

; Colores del TMS9918 en 5 bits por componente (R, G, B).
V9_PALETA_TMS:
    DB  0,  0,  0,   0,  0,  0,   4, 25,  8,  11, 27, 15
    DB 10, 10, 29,  15, 14, 31,  26, 10,  9,   8, 29, 30
    DB 31, 10, 10,  31, 15, 15,  26, 24, 10,  28, 25, 16
    DB  4, 22,  7,  25, 11, 23,  25, 25, 25,  31, 31, 31

; --------------------------------------------------------------
;  V9_CARGAR_COLOR_LABERINTO: A = byte de color del TMS (tinta en el
;  nibble alto, fondo en el bajo) -> entradas 17 (fondo) y 18 (tinta)
;  de la paleta. El color 0 del TMS (transparente) se ve negro, como
;  el borde que deja el juego.
; --------------------------------------------------------------
V9_CARGAR_COLOR_LABERINTO:
    LD (V9_COLOR_NIVEL), A
    PUSH AF
    LD B, 14
    LD A, 17 * 4
    CALL V9_ESCRIBIR_REG
    POP AF
    PUSH AF
    CALL .UN_COLOR              ; fondo
    POP AF
    RRCA
    RRCA
    RRCA
    RRCA                        ; tinta
.UN_COLOR:
    AND $0F
    JR NZ, .OPACO
    INC A
.OPACO:
    LD L, A
    ADD A, A
    ADD A, L                    ; 3 bytes por color
    LD HL, V9_PALETA_TMS
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO
    INC H
.SIN_ACARREO:
    LD BC, 3 * 256 + V9_PALETA
    OTIR
    RET

; --------------------------------------------------------------
;  V9_CONVERTIR_LOSETAS: GRAFICOS_LOSETAS (91 x 32 bytes, 16 filas de
;  2 bytes) -> generador de la capa B a 4 bpp. La fila f de la
;  loseta t va a $40000 + ((t div 16)*16 + f)*128 + (t mod 16)*8.
; --------------------------------------------------------------
V9_CONVERTIR_LOSETAS:
    LD HL, GRAFICOS_LOSETAS
    LD C, 0                     ; t
.LOSETA:
    LD B, 0                     ; f
.FILA:
    PUSH HL
    PUSH BC
    ; direccion = ((t>>4)*16 + f)*128 + (t&15)*8, mas $40000
    LD A, C
    AND $F0
    OR B                        ; (t>>4)*16 + f, ya en su sitio
    LD H, 0
    LD L, A
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL                  ; *128
    LD A, C
    AND $0F
    ADD A, A
    ADD A, A
    ADD A, A
    OR L
    LD L, A
    LD A, $04
    CALL V9_DIRECCION
    POP BC
    POP HL
    CALL .BYTE
    CALL .BYTE
    INC B
    BIT 4, B
    JR Z, .FILA
    INC C
    LD A, C
    CP 91
    JR NZ, .LOSETA
    RET
; 8 pixeles de 1 bpp en (HL) -> 4 bytes a 4 bpp; avanza HL.
.BYTE:
    LD D, (HL)
    INC HL
    LD E, 4
.PAREJA:
    XOR A
    RL D
    ADC A, A
    RL D
    ADC A, A                    ; A = 2 bits (izquierda en el bit 1)
    PUSH HL
    LD HL, .PAREJAS
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO
    INC H
.SIN_ACARREO:
    LD A, (HL)
    POP HL
    OUT (V9_VRAM), A
    DEC E
    JR NZ, .PAREJA
    RET
.PAREJAS:
    DB $11, $12, $21, $22

; --------------------------------------------------------------
;  V9_TIC: lo llama WAIT_VBLANK_OPT una vez por tic, despues del
;  volcado al TMS. Actualiza el color del laberinto, las losetas que
;  hayan cambiado y el scroll pendiente. Conserva IX e IY.
; --------------------------------------------------------------
V9_TIC:
    LD A, (V9_PRESENTE)
    AND A
    RET Z
    ; --- color del laberinto, el mismo que pinta ACTUALIZAR_VRAM_FRAME_OPT ---
    LD A, (REGISTRO_NIVEL_ICONO_HUD)
    CALL CONSULTAR_COLOR_VDP
    LD HL, V9_COLOR_NIVEL
    CP (HL)
    JR Z, .COLOR_IGUAL
    DI
    CALL V9_CARGAR_COLOR_LABERINTO
    EI
.COLOR_IGUAL:
    ; --- nivel recien cargado: matriz entera ---
    LD A, (V9_NIVEL_NUEVO)
    AND A
    JR Z, .ZONA_VISIBLE
    XOR A
    LD (V9_NIVEL_NUEVO), A
    LD B, 8
    LD A, $C2                   ; pantalla activa
    DI
    CALL V9_ESCRIBIR_REG
    EI
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
    LD A, L
    LD (V9_SCROLL_NUEVO + 0), A ; SCBY0
    LD A, H
    AND $01
    LD (V9_SCROLL_NUEVO + 1), A ; SCBY1
    EX DE, HL
    LD BC, -V9_VENTANA_X
    ADD HL, BC
    LD A, L
    AND $07
    LD (V9_SCROLL_NUEVO + 2), A ; SCBX0
    SRL H
    RR L
    SRL H
    RR L
    SRL H
    RR L
    LD A, L
    AND $3F
    LD (V9_SCROLL_NUEVO + 3), A ; SCBX1
    PUSH DE
    LD HL, V9_SCROLL_NUEVO
    LD DE, V9_SCROLL
    LD BC, 4
    DI                          ; que V9_ISR no lea un valor a medias
    LDIR
    EI
    POP DE
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
    JP V9_COMPARAR_FILA
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

V9_NIVEL_NUEVO: DB 0            ; 1 tras CARGAR_NIVEL: el proximo tic vuelca la matriz entera

; --------------------------------------------------------------
;  V9_CARGAR_NIVEL: parche al principio de CARGAR_NIVEL (partida y
;  demo). Marca el nivel nuevo y hace la instruccion sustituida.
; --------------------------------------------------------------
V9_CARGAR_NIVEL:
    LD A, 1
    LD (V9_NIVEL_NUEVO), A
    LD A, (NIVEL_ACTUAL)
    RET

; --------------------------------------------------------------
;  V9_COMPARAR_FILA: fila B (< 29), E columnas (1-32) desde la C,
;  dando la vuelta en la 32. Vuelca al V9990 las losetas que no
;  coinciden con la sombra y actualiza la sombra. El bucle de
;  comparacion (V9_COMPARAR_TRAMO) son ~50 ciclos por loseta.
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
;  V9_ESCRIBIR_LOSETA: loseta A en la fila B, columna C (0-31) de la
;  capa B. Patron de arriba a la izquierda p = (t div 16)*64 +
;  (t mod 16)*2; los otros tres son p+1, p+32 y p+33.
;  Conserva BC y DE.
; --------------------------------------------------------------
V9_ESCRIBIR_LOSETA:
    PUSH BC
    PUSH DE
    AND $7F
    LD E, A
    AND $0F
    ADD A, A
    LD D, A                     ; (t mod 16)*2
    LD A, E
    AND $70
    RRCA
    RRCA
    RRCA
    RRCA                        ; t div 16 (0-7)
    LD L, 0
    RRA
    RR L
    RRA
    RR L
    LD H, A                     ; HL = (t div 16)*64
    LD A, L
    OR D
    LD E, A
    LD D, H                     ; DE = p
    LD A, C
    AND 31
    ADD A, A
    ADD A, A
    LD L, A                     ; columna*4
    LD A, B
    ADD A, $E0
    LD H, A                     ; $E000 + fila*256 (+ $70000)
    DI
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

FIN_V9990:
    ASSERT FIN_V9990 <= SOMBRA_MATRIZ
