; ==============================================================
;  v9_portada.asm -- Mad Mix Game v9990: portada del V9990 en modo
;  bitmap (f2g)
;
;  La portada nueva del grafista (graficos/remake/portada.bmp) tiene 62
;  colores, que no caben en una capa del modo P1 (16). Se muestra en el
;  modo B1 (256 x 212, 8 bpp, BP6: paleta de 64 colores). El cargador
;  de la ROM (V9_DESCOMPRIMIR) la deja en la direccion $60000 del modo
;  bitmap con su paleta detras. Al entrar en la portada se guarda la
;  paleta del juego y al salir se repone.
;
;  Vive en $F010, detras del lienzo del TMS (BUFFER_LOSETAS_TRABAJO,
;  hasta $F003) y lejos de la pila ($F2FF hacia abajo). Solo se usa con
;  el V9990.
; ==============================================================

PORTADA_BITMAP  EQU $60000      ; tools/graficos.py (PORTADA_VRAM)
PORTADA_PALETA  EQU PORTADA_BITMAP + 256 * 212

    ORG $F010
; Entrar en la portada (V9_PONER_MODO, con las interrupciones cerradas).
V9_PORTADA_ENTRAR:
    ; paleta del juego -> V9_PALETA_COPIA
    XOR A
    LD B, 14
    CALL V9_ESCRIBIR_REG        ; R#14: entrada 0
    LD HL, V9_PALETA_COPIA
    LD BC, 192 * 256 + V9_PALETA
    INIR
    ; modo B1, 256 px, 8 bpp; paleta de 64 colores (BP6)
    LD B, 6
    LD A, $82
    CALL V9_ESCRIBIR_REG
    LD B, 13
    XOR A
    CALL V9_ESCRIBIR_REG
    ; la imagen empieza en la linea PORTADA_BITMAP / 256
    LD B, 17
    LD A, LOW (PORTADA_BITMAP / 256)
    CALL V9_ESCRIBIR_REG
    LD B, 18
    LD A, HIGH (PORTADA_BITMAP / 256)
    CALL V9_ESCRIBIR_REG
    LD B, 19
    XOR A
    CALL V9_ESCRIBIR_REG
    LD B, 20
    XOR A
    CALL V9_ESCRIBIR_REG
    ; su paleta, desde la VRAM (ya en modo bitmap)
    LD HL, PORTADA_PALETA & $FFFF
    LD A, PORTADA_PALETA >> 16
    CALL V9_DIRECCION_LECTURA
    XOR A
    LD B, 14
    CALL V9_ESCRIBIR_REG
    LD B, 192
.PALETA:
    IN A, (V9_VRAM)
    OUT (V9_PALETA), A
    DJNZ .PALETA
    LD B, 8
    LD A, $C2                   ; pantalla encendida, sin sprites
    JP V9_ESCRIBIR_REG

; Salir de la portada (V9_PONER_MODO, antes de cambiar de modo; A =
; modo nuevo, se conserva).
V9_PORTADA_SALIR:
    PUSH AF
    LD A, (V9_MODO)
    CP MODO_PORTADA
    JR NZ, .FIN
    LD B, 6
    LD A, $05                   ; P1
    CALL V9_ESCRIBIR_REG
    LD B, 17
    XOR A
    CALL V9_ESCRIBIR_REG
    LD B, 18
    XOR A
    CALL V9_ESCRIBIR_REG
    XOR A
    LD B, 14
    CALL V9_ESCRIBIR_REG
    LD HL, V9_PALETA_COPIA
    LD BC, 192 * 256 + V9_PALETA
    OTIR
.FIN:
    POP AF
    RET

; --------------------------------------------------------------
;  V9_FILA_A_CAPA: final de V9_PASO (espejo del TMS). A = fila, ya
;  leida en V9_BUF_PATRONES/V9_BUF_COLORES. Las celdas vacias (patron a
;  0 y fondo transparente o negro, que se ven negras), casi todas en los
;  menus, no se convierten: su nombre es el patron negro. Las demas se
;  convierten por tramos seguidos y su nombre es fila*32 + c.
; --------------------------------------------------------------
V9_FILA_A_CAPA:
    PUSH AF
    ; mapa de celdas vacias (1) y llenas (0)
    LD HL, V9_BUF_PATRONES
    LD DE, V9_VACIAS
.MAPA:
    LD B, 8
    XOR A
.MAPA_PATRON:
    OR (HL)
    INC L
    DJNZ .MAPA_PATRON
    AND A
    JR NZ, .LLENA
    INC H
    LD A, L
    SUB 8
    LD L, A
    LD B, 8
    XOR A
.MAPA_COLOR:
    OR (HL)
    INC L
    DJNZ .MAPA_COLOR
    DEC H
    AND $0E
    JR NZ, .LLENA
    INC A
    JR .GUARDAR
.LLENA:
    XOR A
.GUARDAR:
    LD (DE), A
    INC E
    LD A, E
    CP LOW (V9_VACIAS + 32)
    JR NZ, .MAPA
    ; tramos de celdas llenas
    LD C, 0
.SALTAR:
    LD A, C
    CP 32
    JR Z, .NOMBRES
    ADD A, LOW V9_VACIAS
    LD L, A
    LD H, HIGH V9_VACIAS
    LD A, (HL)
    AND A
    JR Z, .TRAMO
    INC C
    JR .SALTAR
.TRAMO:
    LD B, 0
.CONTAR:
    INC B
    INC L
    LD A, C
    ADD A, B
    CP 32
    JR Z, .CONVERTIR
    LD A, (HL)
    AND A
    JR Z, .CONTAR
.CONVERTIR:
    POP AF
    PUSH AF
    PUSH BC
    CALL V9_CONVERTIR_CELDAS    ; fila A, celdas C a C+B-1
    POP BC
    LD A, C
    ADD A, B
    LD C, A
    JR .SALTAR
    ; nombres de la fila (fila + 1 de la capa A)
.NOMBRES:
    POP AF
    LD L, A
    LD H, 0
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    ADD HL, HL
    EX DE, HL                   ; DE = fila*32
    INC A
    LD H, A
    LD L, 0
    CALL V9_DIRECCION_NOMBRE_A
    LD HL, V9_VACIAS
    LD B, 32
.NOMBRE:
    LD A, (HL)
    AND A
    JR NZ, .NEGRO
    LD A, E
    OUT (V9_VRAM), A
    LD A, D
    OUT (V9_VRAM), A
    JR .SIGUIENTE
.NEGRO:
    LD A, LOW V9_PAT_NEGRO
    OUT (V9_VRAM), A
    LD A, HIGH V9_PAT_NEGRO
    OUT (V9_VRAM), A
.SIGUIENTE:
    INC DE
    INC L
    DJNZ .NOMBRE
    ; con la pantalla recien limpiada, el espejo se ve cuando esta entero
    LD A, (V9_ESPEJO_OCULTO)
    AND A
    JR Z, .FIN
    LD HL, V9_ESP_VALIDA
    LD B, 24
.VALIDA:
    LD A, (HL)
    AND A
    JR Z, .FIN
    INC HL
    DJNZ .VALIDA
    XOR A
    LD (V9_ESPEJO_OCULTO), A
    LD C, 16
    LD HL, V9_PALETA_TMS
    CALL V9_CARGAR_PALETA       ; A = 0: entradas 0-15
.FIN:
    EI
    RET

; V9_PONER_MODO, al entrar en el modo espejo: paleta 0-15 en negro hasta
; que V9_FILA_A_CAPA haya copiado todas las filas.
V9_ESPEJO_OCULTAR:
    LD A, 1
    LD (V9_ESPEJO_OCULTO), A
    XOR A
    LD B, 14
    CALL V9_ESCRIBIR_REG
    LD B, 48
.NEGRO:
    OUT (V9_PALETA), A
    DJNZ .NEGRO
    RET
V9_ESPEJO_OCULTO: DB 0

; color A -> V9_T4 (V9_CONVERTIR_CELDAS.TABLA) y V9_NT: el par de bytes
; de cada cuarteto n es V9_T4[n >> 2], V9_T4[n & 3]. Devuelve E = A y
; B = HIGH V9_NT (V9_CELDAS).
V9_NT_COLOR:
    CALL V9_CONVERTIR_CELDAS.TABLA
    PUSH HL
    PUSH DE
    LD HL, V9_NT
    LD DE, V9_T4
    LD C, 4
.ALTO:
    LD A, (DE)                  ; V9_T4[n >> 2]
    PUSH DE
    LD DE, V9_T4
    LD B, 4
.BAJO:
    LD (HL), A
    INC L
    EX AF, AF'
    LD A, (DE)                  ; V9_T4[n & 3]
    LD (HL), A
    INC L
    INC DE
    EX AF, AF'
    DJNZ .BAJO
    POP DE
    INC DE
    DEC C
    JR NZ, .ALTO
    POP DE
    POP HL
    LD B, HIGH V9_NT
    RET

; --------------------------------------------------------------
;  V9_ISR_TMS: la ISR del TMS (ENTRADA_INTERRUPCION_VBLANK) cuando hay
;  V9990, igual pero con las interrupciones abiertas mientras cuenta el
;  frame y suena la musica (hasta 4 ms con algunos efectos). En una
;  maquina real los dos VDP no van a la par: si el fin de pantalla del
;  V9990 llegaba durante esa ISR, el scroll se escribia con la imagen
;  siguiente ya empezada (a 60 Hz el V9990 solo tiene unos 3 ms sin
;  imagen) y la pantalla se partia y temblaba. Ahora V9_ISR lo atiende
;  en cuanto llega. El estado del TMS se lee antes del EI y la escritura
;  del registro 1 (dos OUT) se hace otra vez con DI.
; --------------------------------------------------------------
V9_ISR_TMS:
    PUSH AF
    IN A, ($99)
    AND A
    JP P, .FIN
.ATENDER:
    PUSH HL
    PUSH DE
    PUSH BC
    EXX
    EX AF, AF'
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    PUSH IX
    PUSH IY
    EI
    CALL GESTIONAR_FRAME
    CALL DESPACHAR_SONIDO_OPT
    DI
    POP IY
    POP IX
    POP BC
    POP DE
    POP HL
    POP AF
    EX AF, AF'
    EXX
    POP BC
    POP DE
    POP HL
    IN A, ($99)
    LD A, (VDP_REGISTRO1_PENDIENTE)
    OUT ($99), A
    LD A, $81
    OUT ($99), A
.FIN:
    POP AF
    EI
    RET

; --------------------------------------------------------------
;  V9_PARPADEO: desde V9_TIC, una vez por tic (10 por segundo). En los 3
;  ultimos segundos de la bola de poder y del hipopotamo
;  (MODO_ESPECIAL_CUENTA_ATRAS < 30) se alterna cada medio segundo (5
;  tics): el comecocos rojo con el amarillo (V9_AMARILLO, que mira
;  V9_PAC_AMARILLO) y el rosa del hipopotamo con el amarillo (entrada 15
;  de la paleta de los sprites, que solo usa el hipopotamo).
; --------------------------------------------------------------
V9_PARPADEO:
    LD A, (MODO_ESPECIAL)
    AND $07
    LD C, A
    LD B, 0                     ; 0: su color, 1: amarillo
    DEC A
    CP 2
    JR NC, .FASE                ; ni bola de poder (1) ni hipopotamo (2)
    LD A, (MODO_ESPECIAL_CUENTA_ATRAS)
    CP 30
    JR NC, .FASE
    LD B, 1
.DIV5:
    INC B
    SUB 5
    JR NC, .DIV5
    LD A, B
    AND 1                       ; amarillo con 25-29, 15-19 y 5-9
    LD B, A
.FASE:
    LD A, C
    DEC A
    LD A, B
    JR Z, .PAC
    XOR A
.PAC:
    LD (V9_AMARILLO), A
    LD A, C
    CP 2
    LD A, B
    JR Z, .HIPO
    XOR A
.HIPO:
    LD HL, V9_HIPO_AMARILLO
    CP (HL)
    RET Z
    LD (HL), A
    LD HL, V9_PALETA_SPRITES + 15 * 3
    AND A
    JR Z, .COLOR
    LD HL, V9_PALETA_SPRITES + 10 * 3    ; el amarillo del comecocos
.COLOR:
    LD A, 32 + 15
    LD C, 1
    DI
    CALL V9_CARGAR_PALETA
    EI
    RET
V9_AMARILLO:      DB 0
V9_HIPO_AMARILLO: DB 0

FIN_V9_PORTADA:
    ASSERT FIN_V9_PORTADA <= $F200

; Variables sin cargar, en la zona de PEPSI_DELTA (solo la usa el TMS)
V9_PALETA_COPIA EQU $7A00       ; 192 bytes: paleta del juego durante la portada
V9_VACIAS       EQU $7AC0       ; 32 bytes: celdas vacias de la fila del espejo
    ASSERT V9_NT + 34 <= V9_PALETA_COPIA
