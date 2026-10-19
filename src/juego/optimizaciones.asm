; ==============================================================
;  optimizaciones.asm -- Mad Mix Game v9990, juego base optimizado
;
;  Codigo nuevo en la zona libre $6500-$83FF (el original no la usa).
;  El motor original solo se toca con 4 parches del mismo tamano
;  (ver "PROYECTO" en madmix1_body.asm), asi que ninguna direccion del
;  juego se desplaza. Medicion de partida: ANALISIS_RENDIMIENTO.md.
;
;  1. El trabajo de frame (volcado de BUFFER_LOSETAS_TRABAJO a VRAM y
;     resto de GESTIONAR_FRAME) sale de la interrupcion. La ISR solo
;     cuenta frames y hace sonar el PSG, asi que ya no se pierden
;     interrupciones (antes un 35-38 %) y la musica va a su tempo.
;  2. El bucle principal avanza a ritmo fijo: TIC_FRAMES frames por
;     tic (5 a 50 Hz, 6 a 60 Hz = 10 tics/s, la media del original).
;  3. Se elimina el LDIR $4000->$4000 de 1323 bytes que el original
;     ejecutaba en cada tic sin efecto (~28 000 ciclos).
;  4. Volcado desenrollado: 30 ciclos por byte en vez de ~36, por
;     encima del minimo del TMS9918 en pantalla activa (~29).
; ==============================================================

    ASSERT $ == $6500
TIC_FRAMES:         DB 6        ; frames por tic; lo fija el cargador (5 o 6)
CONTADOR_FRAMES:    DB 0        ; lo incrementa la ISR en cada VBLANK
ULTIMO_FLANCO:      DB 0        ; CONTADOR_FRAMES al empezar el ultimo volcado

; --------------------------------------------------------------
;  GESTIONAR_FRAME_OPT: lo que queda de GESTIONAR_FRAME dentro de la
;  ISR. Solo cuenta el frame; el trabajo lo hace WAIT_VBLANK_OPT.
; --------------------------------------------------------------
GESTIONAR_FRAME_OPT:
    LD HL, CONTADOR_FRAMES
    INC (HL)
    XOR A
    LD (FRAME_FLAG), A          ; por compatibilidad: semaforo siempre libre
    RET

; --------------------------------------------------------------
;  WAIT_VBLANK_OPT: mismo contrato que WAIT_VBLANK (espera al
;  siguiente VBLANK, hace el trabajo de frame una vez, vuelve con
;  interrupciones activas y A=0/Z), pero el trabajo se hace aqui, en
;  el contexto del bucle, con las interrupciones abiertas entre filas.
;  Conserva todos los registros salvo AF, igual que hacia la ISR.
; --------------------------------------------------------------
WAIT_VBLANK_OPT:
    PUSH HL
    EI
    LD HL, CONTADOR_FRAMES
    LD A, (HL)
.ESPERAR_FLANCO:
    CP (HL)
    JR Z, .ESPERAR_FLANCO
    LD A, (HL)
    LD (ULTIMO_FLANCO), A
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
    CALL ACTUALIZAR_VRAM_FRAME_OPT
    DI                          ; el resto, como en la ISR original
    CALL CONTINUAR_CAPTURA_MASCARAS_ACTORES
    CALL RESET_CONTADOR_ACTORES
    CALL VACIAR_COLA_REDIBUJADO
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
    EI
    XOR A
    RET

; --------------------------------------------------------------
;  ESPERAR_TIC: sustituye a WAIT_VBLANK en BUCLE_PRINCIPAL_JUEGO.
;  Espera hasta que el siguiente VBLANK caiga TIC_FRAMES frames
;  despues del ultimo volcado; si el tic se paso de tiempo no espera
;  (se resincroniza solo).
; --------------------------------------------------------------
ESPERAR_TIC:
    EI
    PUSH HL
.BUCLE:
    LD HL, ULTIMO_FLANCO
    LD A, (CONTADOR_FRAMES)
    SUB (HL)
    INC A                       ; flanco que esperara WAIT_VBLANK_OPT
    LD HL, TIC_FRAMES
    CP (HL)
    JR C, .BUCLE
    POP HL
    JP WAIT_VBLANK_OPT

; --------------------------------------------------------------
;  ACTUALIZAR_VRAM_FRAME_OPT: equivalente a ACTUALIZAR_VRAM_FRAME sin
;  el LDIR de relleno y con el volcado desenrollado. Cada ventana de
;  escritura en VRAM empieza fijando su direccion (SETVRAM) con las
;  interrupciones cerradas, asi que la ISR puede entrar entre filas
;  aunque reescriba el registro 1 del VDP.
; --------------------------------------------------------------
ACTUALIZAR_VRAM_FRAME_OPT:
    DI
    LD HL, FLAG_NIVEL_RECIEN_CARGADO
    LD A, (HL)
    LD (HL), 0
    AND A
    LD A, (REGISTRO_NIVEL_ICONO_HUD)
    LD HL, ULTIMO_ICONO_HUD_CACHEADO
    JR NZ, .REDIBUJAR_ICONO_HUD
    CP (HL)
    JR Z, .COLORES_DESTELLO
.REDIBUJAR_ICONO_HUD:
    LD (HL), A
    CALL CONSULTAR_COLOR_VDP
    LD HL, $2220                ; tabla de color, misma zona que el original
    LD D, $12
.BUCLE_RELLENO_ICONO_HUD:
    LD BC, 192
    PUSH HL
    CALL FILVRM                 ; FILVRM cierra y vuelve a abrir interrupciones
    POP HL
    INC H
    DEC D
    JR NZ, .BUCLE_RELLENO_ICONO_HUD
.COLORES_DESTELLO:
    LD A, (COLOR_ACTUAL)
    CALL CONSULTAR_COLOR_VDP
    LD HL, ZONA_COLOR_VRAM_DESTELLO_A
    LD BC, 16
    CALL FILVRM
    LD HL, ZONA_COLOR_VRAM_DESTELLO_B
    LD BC, 16
    CALL FILVRM

    LD HL, BUFFER_LOSETAS_TRABAJO
    LD DE, ZONA_PATRON_VRAM_LABERINTO
    LD B, 18                    ; 18 filas de caracteres
.BUCLE_FILA:
    DI
    PUSH BC
    EX DE, HL
    CALL SETVRAM
    EX DE, HL
    LD C, $98
    CALL VOLCAR_FILA_CARACTERES
    POP BC
    EI                          ; aqui puede entrar la VBLANK pendiente
    INC H                       ; siguiente fila del buffer (pagina de 256 bytes)
    INC D                       ; siguiente fila de la tabla de patrones
    DJNZ .BUCLE_FILA
    RET

; --------------------------------------------------------------
;  VOLCAR_FILA_CARACTERES: 24 caracteres x 8 lineas de la fila H del
;  buffer, en el orden de la tabla de patrones (caracter a caracter).
;  El byte (columna c, linea y) esta en L = $04 + c + 32*y, igual que
;  en el bucle original. 30 ciclos por byte entre OUT y OUT.
; --------------------------------------------------------------
VOLCAR_FILA_CARACTERES:
.C = 0
    DUP 24
.Y = 0
    DUP 8
    LD L, $04 + .C + 32 * .Y
    LD A, (HL)
    OUT (C), A
.Y = .Y + 1
    EDUP
.C = .C + 1
    EDUP
    RET

FIN_OPTIMIZACIONES:
    ASSERT FIN_OPTIMIZACIONES <= $8400
