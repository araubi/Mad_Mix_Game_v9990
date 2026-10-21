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
;  5. Espejo de actores con tabla (INVERTIR_BITS_OPT) y desplazamiento
;     sub-pixel 6 en 2 pasos (DIBUJAR_FILA_DESPLAZADA_6): los actores y
;     el scroll horizontal son lo que hace pasarse de tiempo a un tic.
;  6. Paso fijo con recuperacion de un frame (ESPERAR_TIC).
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
    POP HL
; Entrada con el VBLANK ya atendido (ESPERAR_TIC la usa si el haz
; aun no ha llegado a la ventana en este frame).
VOLCAR_TRAS_FLANCO:
    PUSH HL
    LD A, (CONTADOR_FRAMES)
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
    CALL VOLCADO_HAZ            ; volcado sincronizado con el haz (volcado_haz.asm)
    CALL V9_TIC                 ; V9990: losetas cambiadas y scroll (v9990.asm)
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
;  ESPERAR_TIC: sustituye a WAIT_VBLANK en BUCLE_PRINCIPAL_JUEGO y en
;  la demo. Paso fijo con recuperacion: el volcado de cada tic debe
;  empezar en el VBLANK numero OBJETIVO_TIC. Si un tic llega tarde un
;  frame, el siguiente se adelanta ese frame (el juego mantiene
;  10 tics/s de media y el retraso no se acumula); si llega tarde mas
;  de un frame, o es el primer tic tras una pausa, se resincroniza sin
;  recuperar, para que nunca haya dos tics seguidos demasiado juntos.
;  Mismo contrato que WAIT_VBLANK: conserva todo salvo AF, A=0/Z.
; --------------------------------------------------------------
ESPERAR_TIC:
    EI
    PUSH HL
    PUSH BC
    LD HL, CONTADOR_FRAMES
    LD A, (OBJETIVO_TIC)
    SUB (HL)
    DEC A                       ; d - 1
    LD B, A
    LD A, (TIC_FRAMES)
    DEC A
    CP B
    CALL NC, TRASPONER_ANTES    ; 1 <= d <= TIC_FRAMES: sobra tiempo antes del VBLANK
.ESPERAR:
    LD A, (OBJETIVO_TIC)
    SUB (HL)                    ; d = frames que faltan hasta el objetivo
    JR Z, .EN_OBJETIVO
    CP 2
    JR C, .LISTO                ; d <= 1 (o ya pasado): toca volcar en el siguiente VBLANK
    LD B, A
    LD A, (TIC_FRAMES)
    CP B
    JR NC, .ESPERAR             ; 2 <= d <= TIC_FRAMES: esperar
                                ; d mayor: objetivo sin sentido (pausa, primer tic) -> no esperar
.LISTO:
    POP BC
    POP HL
    CALL WAIT_VBLANK_OPT        ; vuelca; ULTIMO_FLANCO = VBLANK real del volcado
.VOLCADO_HECHO:
    PUSH HL
    LD HL, OBJETIVO_TIC
    LD A, (ULTIMO_FLANCO)
    SUB (HL)                    ; retraso respecto al objetivo
    CP 2
    LD A, (ULTIMO_FLANCO)
    JR NC, .RESINCRONIZAR       ; retraso >= 2, o negativo (objetivo viejo)
    LD A, (HL)                  ; retraso 0 o 1: el siguiente objetivo es este + N
.RESINCRONIZAR:
    LD H, A
    LD A, (TIC_FRAMES)
    ADD A, H
    LD (OBJETIVO_TIC), A
    POP HL
    XOR A
    RET
.EN_OBJETIVO:
    ; El VBLANK objetivo ya ha pasado. Si el haz aun no ha llegado a la
    ; ventana, el volcado sincronizado todavia cabe en este frame.
    CALL HAZ_PASADO
    JR NZ, .LISTO               ; ya paso: al siguiente VBLANK, como antes
    POP BC
    POP HL
    CALL VOLCAR_TRAS_FLANCO
    JR .VOLCADO_HECHO

OBJETIVO_TIC: DB 0

; --------------------------------------------------------------
;  ACTUALIZAR_VRAM_FRAME_OPT: equivalente a ACTUALIZAR_VRAM_FRAME sin
;  el LDIR de relleno y con el volcado desenrollado. Cada ventana de
;  escritura en VRAM empieza fijando su direccion (SETVRAM) con las
;  interrupciones cerradas, asi que la ISR puede entrar entre filas
;  aunque reescriba el registro 1 del VDP.
; --------------------------------------------------------------
ACTUALIZAR_VRAM_FRAME_OPT:
    CALL ACTUALIZAR_COLORES_OPT
    JR VOLCAR_BUFFER_SIN_SINCRONIZAR

; --------------------------------------------------------------
;  ACTUALIZAR_COLORES_OPT: primera parte del trabajo de frame
;  (icono del HUD y colores del destello). La usa tambien el
;  volcado sincronizado con el haz (volcado_haz.asm).
; --------------------------------------------------------------
ACTUALIZAR_COLORES_OPT:
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
    JP FILVRM

VOLCAR_BUFFER_SIN_SINCRONIZAR:
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

; --------------------------------------------------------------
;  INVERTIR_BITS_OPT: sustituye a INVERTIR_BITS_PATRON_ACTOR (espejo
;  horizontal del patron fuente del actor, en su sitio). Mismo
;  resultado: cada bloque de n bytes ($8435) queda invertido de orden y
;  con los bits de cada byte en espejo, para 48 bloques desde ($8433).
;  El original invertia bit a bit (8 RLC/RRA por byte, ~170 ciclos por
;  byte contando el LDIR de vuelta); aqui se intercambian los bytes de
;  los extremos hacia el centro y el espejo sale de TABLA_ESPEJO
;  (~65 ciclos por byte). Se llama mucho cuando varios actores
;  comparten patron y miran a lados distintos (el patron se voltea y
;  se vuelve a voltear en cada dibujado).
;  Entrada como el original; sale por SALIR_MOTOR_ACTORES.
; --------------------------------------------------------------
INVERTIR_BITS_OPT:
    PUSH AF
    PUSH HL
    PUSH DE
    PUSH BC
    EXX
    PUSH HL
    PUSH BC
    LD H, HIGH TABLA_ESPEJO     ; H' = pagina de la tabla
    EXX
    LD HL, ($8433)
    LD A, 48
.BUCLE_BLOQUES:
    PUSH AF
    LD A, ($8435)
    LD C, A
    LD B, 0
    PUSH HL
    ADD HL, BC                  ; HL = inicio del bloque siguiente
    EX (SP), HL                 ; pila = siguiente, HL = inicio
    LD D, H
    LD E, L
    ADD HL, BC
    DEC HL
    EX DE, HL                   ; HL = primer byte, DE = ultimo
    LD A, C
    SRL A                       ; A = numero de parejas, CF = hay byte central
    PUSH AF
    JR Z, .SIN_PAREJAS
    LD B, A
.BUCLE_PAREJA:
    LD A, (HL)
    EXX
    LD L, A
    LD C, (HL)                  ; C' = espejo(primero)
    EXX
    LD A, (DE)
    EXX
    LD L, A
    LD A, (HL)                  ; A = espejo(ultimo)
    EXX
    LD (HL), A
    EXX
    LD A, C
    EXX
    LD (DE), A
    INC HL
    DEC DE
    DJNZ .BUCLE_PAREJA
.SIN_PAREJAS:
    POP AF
    JR NC, .SIGUIENTE_BLOQUE
    LD A, (HL)                  ; byte central: solo espejo
    EXX
    LD L, A
    LD A, (HL)
    EXX
    LD (HL), A
.SIGUIENTE_BLOQUE:
    POP HL
    POP AF
    DEC A
    JR NZ, .BUCLE_BLOQUES
    EXX
    POP BC
    POP HL
    EXX
    JP SALIR_MOTOR_ACTORES

; --------------------------------------------------------------
;  ELEGIR_VARIANTE_OPT: parche en MOTOR_ACTORES.CONTINUAR_TRAS_ELEGIR_
;  DIRECCION (sustituye a AND $07 / EXX / LD C,A / EXX). Si el actor
;  va con desplazamiento sub-pixel 6 hacia la derecha, usa
;  DIBUJAR_FILA_DESPLAZADA_6 en vez del bucle de 6 pasos bit a bit.
; --------------------------------------------------------------
ELEGIR_VARIANTE_OPT:
    AND $07
    CP 6
    JR NZ, .FIN
    PUSH HL
    PUSH IY
    POP HL
    LD A, L
    CP LOW DIBUJAR_FILA_DESPLAZADA_DERECHA
    JR NZ, .NO_ES_DERECHA
    LD A, H
    CP HIGH DIBUJAR_FILA_DESPLAZADA_DERECHA
    JR NZ, .NO_ES_DERECHA
    LD IY, DIBUJAR_FILA_DESPLAZADA_6
.NO_ES_DERECHA:
    POP HL
    LD A, 6
.FIN:
    EXX
    LD C, A
    EXX
    RET

; --------------------------------------------------------------
;  DIBUJAR_FILA_DESPLAZADA_6: como DIBUJAR_FILA_DESPLAZADA_DERECHA con
;  desplazamiento 6, pero hecho como 2 pasos a la IZQUIERDA con un
;  registro mas que recoge lo que sale por arriba (B' para el sprite,
;  B para la mascara, que entra con unos). Resultado identico:
;    sprite S0:S1:S2 (A, L', H')  -> S0>>6, S0<<2|S1>>6, S1<<2|S2>>6
;    mascara M0:M1:M2 (E, D, C)   -> M0>>6|$FC, M0<<2|M1>>6, M1<<2|M2>>6
;  2 pasos de ~90 ciclos en vez de 6 de ~89 por fila. Dos filas por
;  entrada, como el original (la segunda se escribe de derecha a
;  izquierda) y misma salida de bucle que MEZCLAR_Y_AVANZAR_FILA_ACTOR.
; --------------------------------------------------------------
DIBUJAR_FILA_DESPLAZADA_6:
    CALL .DESPLAZAR_IZQUIERDA_2
    LD C, A                     ; C = sprite byte 1
    LD A, (HL)
    AND B                       ; mascara byte 0
    EXX
    OR B                        ; sprite byte 0
    EXX
    LD (HL), A
    INC L
    LD A, (HL)
    AND E
    OR C
    LD (HL), A
    INC L
    LD A, (HL)
    AND D
    EXX
    OR L                        ; sprite byte 2
    EXX
    LD (HL), A
    LD BC, 32
    ADD HL, BC
    DI                          ; siguiente fila del cursor, igual que el original
    LD ($843A), SP
    LD SP, ($843C)
    POP DE
    POP BC
    EXX
    POP HL
    LD ($843C), SP
    LD SP, ($843A)
    EI
    LD A, C
    LD B, A
    EXX
    LD A, B
    CALL .DESPLAZAR_IZQUIERDA_2
    LD C, A
    LD A, (HL)                  ; segunda fila: de derecha a izquierda
    AND D
    EXX
    OR L
    EXX
    LD (HL), A
    DEC L
    LD A, (HL)
    AND E
    OR C
    LD (HL), A
    DEC L
    LD A, (HL)
    AND B
    EXX
    OR B
    EXX
    LD (HL), A
    LD BC, 32
    ADD HL, BC
    EX AF, AF'
    DEC A
    JP NZ, MOTOR_ACTORES.BUCLE_DIBUJAR_ACTOR
    JP SALIR_MOTOR_ACTORES

; Entrada: A=S0, L'=S1, H'=S2, E=M0, D=M1, C=M2 (banco principal activo).
; Salida: B'=sprite0, A=sprite1, L'=sprite2; B=mascara0, E=mascara1, D=mascara2.
.DESPLAZAR_IZQUIERDA_2:
    LD B, $FF
    EXX
    LD B, 0
    SLA H
    RL L
    RLA
    RL B
    SLA H
    RL L
    RLA
    RL B
    EXX
    SLA C
    RL D
    RL E
    RL B
    SLA C
    RL D
    RL E
    RL B
    RET

; --------------------------------------------------------------
;  TABLA_ESPEJO: byte con los bits en orden inverso (256 bytes,
;  alineada a pagina).
; --------------------------------------------------------------
    ALIGN 256
TABLA_ESPEJO:
.V = 0
    DUP 256
    DB ((.V & 1) << 7) | ((.V & 2) << 5) | ((.V & 4) << 3) | ((.V & 8) << 1) | ((.V & 16) >> 1) | ((.V & 32) >> 3) | ((.V & 64) >> 5) | ((.V & 128) >> 7)
.V = .V + 1
    EDUP

FIN_OPTIMIZACIONES:
    ASSERT FIN_OPTIMIZACIONES <= $8400
