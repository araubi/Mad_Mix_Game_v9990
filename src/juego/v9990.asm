; ==============================================================
;  v9990.asm -- Mad Mix Game v9990: parte residente del V9990
;
;  Con un cartucho GFX9000 (V9990) toda la imagen sale por el V9990
;  con los graficos del remake (graficos/remake, del grafista):
;
;  - Laberinto en la capa B del modo P1, con las losetas y la paleta
;    de cada nivel y scroll por hardware (fase F1, ahora con el
;    dibujo del grafista).
;  - Actores como sprites del V9990.
;  - Capa A: el marco y el marcador nuevos durante la partida, la
;    portada nueva, y para el resto de pantallas (menu, creditos,
;    redefinir teclas) un espejo de la pantalla del TMS9918.
;
;  Sin GFX9000 el juego es identico a f1c/f0e (pantalla del TMS).
;
;  Esta parte esta siempre en RAM ($6C00) y solo tiene la ISR, las
;  variables y los enganches con el juego, que miran V9_PRESENTE. El
;  resto (v9990_ext.asm) vive en la RAM baja $0100-$0FFF, que con el
;  V9990 queda libre (sin V9990 el motor de actores usa $0500 y lo
;  machaca, pero entonces no se ejecuta). Los graficos ya convertidos
;  (tools/graficos.py) los sube el cargador de la ROM a la VRAM del
;  V9990 antes de arrancar el juego.
;
;  Enganches en el juego original (mismo tamano, ninguna etiqueta se
;  mueve; ver "PROYECTO V9990" en los cuerpos):
;    $0038                -> V9_ISR (ACTIVAR_INTERRUPCION_MODO_1)
;    CARGAR_NIVEL         -> V9_CARGAR_NIVEL (nivel nuevo, modo juego)
;    MOTOR_ACTORES        -> V9_ACTOR (apunta el actor para los sprites)
;    DIBUJAR_PORTADA      -> V9_PORTADA (modo portada)
;    LIMPIAR_VRAM_AREA_JUEGO -> V9_LIMPIAR (menus: modo espejo)
;    RELLENAR_SOLIDO_AREA_JUEGO_BUFFER_VRAM -> V9_RELLENAR (fin de partida)
;    DIBUJAR_TEXTO_VRAM   -> V9_TEXTO (textos sobre la ventana)
;    DIBUJAR_MARCADOR_PUNTOS -> V9_MARCADOR (texto del marcador)
;    COMPROBAR_PULSACION (6 llamadas) -> V9_PULSACION (espera de tecla)
;    optimizaciones.asm: el volcado al TMS pasa a V9_VOLCADO, y
;    ESPERAR_TIC usa V9_TRASPONER y V9_HAZ_PASADO
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

; Modos de la imagen del V9990
MODO_ESPEJO     EQU 0           ; capa A = copia de la pantalla del TMS
MODO_JUEGO      EQU 1           ; laberinto, sprites, marco y marcador
MODO_PORTADA    EQU 2           ; capa A = portada nueva

    ASSERT $ <= $6C00
    ORG $6C00
V9_INICIAR_ENTRADA:
    JP V9_INICIAR               ; $6C00: lo llama el cargador de la ROM (v9990_ext.asm)
V9_PRESENTE:    DB 0            ; 1 si hay V9990
V9_MODO:        DB MODO_ESPEJO
V9_SCROLL:      DS 4            ; R#21-R#24 (SCBY0, SCBY1, SCBX0, SCBX1) pendientes
V9_SPR_LISTOS:  DB 0            ; 1: V9_ISR copia V9_SPR_BUF a la tabla de sprites
V9_ULTIMO_PASO: DB 0            ; CONTADOR_FRAMES del ultimo paso del espejo

; --------------------------------------------------------------
;  V9_ISR: delante de ENTRADA_INTERRUPCION_VBLANK (ACTIVAR_
;  INTERRUPCION_MODO_1 instala este vector). Si la interrupcion es
;  la de fin de pantalla del V9990, la atiende y vuelve; si a la vez
;  hay una del TMS, la linea de interrupcion sigue activa y se entra
;  otra vez nada mas hacer EI.
;
;  Si el juego estaba parado en un HALT, se vuelve al mismo HALT:
;  asi las pausas hechas con HALT siguen contando solo las
;  interrupciones del TMS (el V9990 interrumpe otras 50/60 veces por
;  segundo y las acortaria a la mitad). Y como el juego no esta a
;  medias de escribir en ningun VDP, es el momento de dar un paso del
;  espejo de la pantalla del TMS.
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
    CALL V9_FIN_PANTALLA        ; scroll y sprites (v9990_ext.asm)
    LD HL, 6
    ADD HL, SP                  ; HL -> direccion de vuelta
    LD C, (HL)
    INC HL
    LD B, (HL)
    DEC BC
    LD A, (BC)
    CP $76                      ; HALT
    JR NZ, .FIN
    PUSH HL
    PUSH BC
    CALL V9_PASO_ESPEJO_ISR
    POP BC
    POP HL
    ; Si el TMS tambien ha interrumpido (en openMSX los dos VDP van a la
    ; par), se atiende aqui mismo y se sigue tras el HALT; si no, se
    ; vuelve al HALT a esperar al TMS.
    IN A, ($99)
    RLCA
    JR C, .TAMBIEN_TMS
    LD (HL), B                  ; vuelve al HALT
    DEC HL
    LD (HL), C
.FIN:
    POP BC
    POP HL
    POP AF
    EI
    RET
.TMS:
    LD A, (V9_PRESENTE)
    AND A
    JR NZ, .TMS_V9990
    POP AF
    JP ENTRADA_INTERRUPCION_VBLANK
    ; Con V9990, la ISR del TMS vuelve por .TRAS_TMS: si el V9990
    ; interrumpiera justo al volver a la instruccion de detras de un
    ; HALT, se confundiria con un HALT a medias y la pausa no avanzaria
    ; nunca (en openMSX los dos VDP interrumpen a la par).
.TMS_V9990:
    POP AF
    PUSH HL
    LD HL, .TRAS_TMS
    EX (SP), HL
    JP ENTRADA_INTERRUPCION_VBLANK
.TAMBIEN_TMS:
    POP BC
    POP HL
    POP AF
    PUSH HL
    LD HL, .TRAS_TMS
    EX (SP), HL
    PUSH AF
    JP ENTRADA_INTERRUPCION_VBLANK.ATENDER  ; con AF ya en la pila y el estado del TMS leido
    ; Aqui una interrupcion del V9990 ya no se confunde con un HALT; si
    ; ha llegado sin que se atendiera aun, se atiende sin volver al HALT.
.TRAS_TMS:
    DI
    PUSH AF
    IN A, (V9_INT_FLAG)
    RRCA
    JR NC, .SIN_V9990
    LD A, 1
    OUT (V9_INT_FLAG), A
    PUSH HL
    PUSH BC
    CALL V9_FIN_PANTALLA
    POP BC
    POP HL
.SIN_V9990:
    POP AF
    EI
    RET

; --------------------------------------------------------------
;  Enganches. Sin V9990 hacen exactamente lo que hacia el juego.
; --------------------------------------------------------------
; CARGAR_NIVEL: avisa del nivel nuevo y hace la instruccion sustituida.
V9_CARGAR_NIVEL:
    LD A, (V9_PRESENTE)
    AND A
    CALL NZ, V9_CARGAR_NIVEL_EXT
    LD A, (NIVEL_ACTUAL)
    RET

; MOTOR_ACTORES: con el V9990 el actor se apunta para los sprites y no
; se dibuja en el buffer del TMS.
V9_ACTOR:
    BIT 7, E                    ; instrucciones sustituidas
    RET NZ
    PUSH AF
    LD A, (V9_PRESENTE)
    AND A
    JR NZ, .V9990
    POP AF
    JP MOTOR_ACTORES + 3
.V9990:
    POP AF
    JP V9_ACTOR_EXT

; DIBUJAR_PORTADA: sustituye a DI / CALL APAGAR_PANTALLA_VDP.
V9_PORTADA:
    DI
    LD A, (V9_PRESENTE)
    AND A
    LD A, MODO_PORTADA
    CALL NZ, V9_PONER_MODO
    JP APAGAR_PANTALLA_VDP

; LIMPIAR_VRAM_AREA_JUEGO (menu, creditos, redefinir teclas): modo espejo.
V9_LIMPIAR:
    LD A, (V9_PRESENTE)
    AND A
    LD A, MODO_ESPEJO
    CALL NZ, V9_PONER_MODO
    JP RELLENAR_SOLIDO_AREA_JUEGO_BUFFER_VRAM

; RELLENAR_SOLIDO_AREA_JUEGO_BUFFER_VRAM: en partida (fin de partida)
; la ventana del TMS se queda en negro; en el V9990, igual.
V9_RELLENAR:
    LD A, (V9_PRESENTE)
    AND A
    CALL NZ, V9_RELLENAR_EXT
    LD DE, BUFFER_LOSETAS_TRABAJO ; instruccion sustituida
    RET

; DIBUJAR_TEXTO_VRAM: dibuja el texto en el TMS y despues lo copia al
; V9990 (sustituye a DI / LD A,(DE) / LD C,A).
V9_TEXTO:
    DI
    LD A, (V9_PRESENTE)
    AND A
    JR Z, .ORIGINAL
    PUSH HL
    PUSH DE
    CALL .ORIGINAL
    POP DE
    POP HL
    JP V9_TEXTO_EXT
.ORIGINAL:
    LD A, (DE)
    LD C, A
    JP DIBUJAR_TEXTO_VRAM + 3

; DIBUJAR_MARCADOR_PUNTOS: IX = texto del marcador (cifras, DEMO o
; BESTIA). Sustituye a LD HL,$16B0.
V9_MARCADOR:
    LD (V9_TEXTO_PUNTOS), IX
    LD HL, V9_MARCADOR_SUCIO
    LD (HL), 1
    LD HL, $16B0
    RET
V9_TEXTO_PUNTOS:   DW 0
V9_MARCADOR_SUCIO: DB 1

; COMPROBAR_PULSACION, desde las esperas de tecla: buen momento para
; un paso del espejo (el juego no esta escribiendo en el TMS).
V9_PULSACION:
    LD A, (V9_PRESENTE)
    AND A
    CALL NZ, V9_PASO_ESPEJO
    JP COMPROBAR_PULSACION

; Volcado de cada tic (VOLCAR_TRAS_FLANCO): con el V9990 no se vuelca
; nada al TMS; V9_TIC actualiza el V9990.
V9_VOLCADO:
    LD A, (V9_PRESENTE)
    AND A
    JP Z, VOLCADO_HAZ
    JP V9_TIC

; ESPERAR_TIC: sin volcado al TMS no hay filas que trasponer ni haz
; que esperar.
V9_TRASPONER:
    LD A, (V9_PRESENTE)
    AND A
    RET NZ
    JP TRASPONER_ANTES

V9_HAZ_PASADO:
    LD A, (V9_PRESENTE)
    AND A
    JP Z, HAZ_PASADO
    XOR A                       ; Z: el tic se hace ya
    RET

FIN_V9990:
    ASSERT FIN_V9990 <= SOMBRA_MATRIZ
