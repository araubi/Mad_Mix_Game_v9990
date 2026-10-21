; ==============================================================
;  volcado_haz.asm -- Mad Mix Game v9990: volcado sin cortes
;
;  El TMS9918 no tiene doble buffer y volcar la ventana (18 filas de
;  24 caracteres, 3456 bytes) cuesta ~1,5 frames, porque en pantalla
;  activa el VDP solo admite un byte cada ~29 ciclos. Si el volcado
;  empieza en el VBLANK, el haz lo alcanza a media ventana y en ese
;  frame se ve una fila a medio escribir: mitad con el scroll nuevo y
;  mitad con el viejo (el "trozo de pared movido" que se ve al hacer
;  scroll, tambien en el juego original).
;
;  Solucion: escribir siempre POR DETRAS del haz. Cada fila se escribe
;  despues de que el haz la haya pintado en el frame N y antes de que
;  la pinte en el frame N+1, asi que el frame N se ve entero viejo y
;  el N+1 entero nuevo.
;   1. Referencia de linea: 5 sprites transparentes en la linea 25
;      (debajo de la fila 0 de la ventana, lineas 16-23). Cuando
;      el haz llega ahi, el VDP activa el indicador de quinto sprite
;      (bit 6 del estado), que se consulta por sondeo. El juego no usa
;      sprites por hardware.
;   2. Las filas que caeran en el borde se trasponen antes al orden de
;      la tabla de patrones: mientras se espera al VBLANK objetivo
;      (ESPERAR_TIC) o, si el tic llega justo, mientras el haz baja
;      hasta la marca.
;   3. Esas filas se envian con OUTI (18 ciclos por byte): fuera de la
;      pantalla activa el VDP admite ese ritmo. El resto, a 30 ciclos.
;   4. La musica de la ISR se aplaza al final del volcado (unos ms),
;      para que no se coma el tiempo del borde.
;  Cuentas a 50 Hz (lineas de openMSX desde el inicio del frame N, 228
;  ciclos por linea): la fila 17 debe acabar antes de la 534. Con 5
;  filas traspuestas acaba hacia la 521. Si el tic llega justo y solo
;  caben 4, la fila que sigue a las rapidas va a 26 ciclos por byte
;  (aun dentro del borde) y acaba hacia la 531. Si caben menos (el tic
;  llego muy tarde), se traspone todo y se vuelca en el frame
;  siguiente. A 60 Hz el frame es demasiado corto: las 4 ultimas filas
;  se ven un frame tarde. Con la pantalla apagada se vuelca sin
;  sincronizar, como antes.
; ==============================================================

FILA_RAPIDA:            EQU 7       ; primera fila tras el VBLANK (cae a mitad de la fila 6)
FILAS_RAPIDAS_50HZ:     EQU 5       ; filas que caben en el borde a 50 Hz (121 lineas)
FILAS_RAPIDAS_60HZ:     EQU 2       ; y a 60 Hz (70 lineas)
Y_MARCA_HAZ:            EQU 24      ; el sprite se ve desde la linea Y+1 = 25 (una de margen)
ATRIBUTOS_SPRITES:      EQU $1B00   ; tabla de atributos de sprites (R#5 = $36)

; --------------------------------------------------------------
;  VOLCADO_HAZ: sustituye a ACTUALIZAR_VRAM_FRAME_OPT en el trabajo de
;  frame. Entra justo despues de un VBLANK (o antes de la linea 25 si
;  viene de ESPERAR_TIC.EN_OBJETIVO). Puede cambiar todos los
;  registros (WAIT_VBLANK_OPT los guarda).
; --------------------------------------------------------------
VOLCADO_HAZ:
    CALL ACTUALIZAR_COLORES_OPT
    XOR A
    LD (SINCRONIZADO), A
    LD A, (VDP_REGISTRO1_PENDIENTE)
    AND $40
    JR NZ, .PANTALLA_ENCENDIDA
    LD (YA_TRASPUESTAS), A      ; pantalla apagada: no hay sprites que marquen
    JR .VOLCAR                  ; el haz, se vuelca sin sincronizar
.PANTALLA_ENCENDIDA:
    CALL ESCRIBIR_MARCA_HAZ
    LD HL, YA_TRASPUESTAS
    LD A, (HL)
    LD (HL), 0
    AND A
    JR NZ, .ESPERAR_HAZ         ; ESPERAR_TIC ya las traspuso antes del VBLANK
    ; --- trasponer filas mientras el haz baja hasta la marca ---
    LD A, 1
    LD (VIGILAR_HAZ), A
    CALL NUMERO_FILAS_RAPIDAS
.TRASPONER:
    LD H, HIGH (BUFFER_LOSETAS_TRABAJO + FILA_RAPIDA * 256)
    LD DE, TRASPUESTA
.SIGUIENTE_TRASPUESTA:
    PUSH BC
    PUSH HL
    PUSH DE
    CALL TRASPONER_FILA
    POP DE
    POP HL
    POP BC
    JR C, .HAZ_LLEGO            ; el haz llego a media fila: esa no cuenta
    LD A, (FILAS_TRASPUESTAS)
    INC A
    LD (FILAS_TRASPUESTAS), A
    INC H
    LD A, E                     ; siguiente fila traspuesta: +192
    ADD A, 192
    LD E, A
    JR NC, $ + 3
    INC D
    DJNZ .SIGUIENTE_TRASPUESTA
    LD A, (VIGILAR_HAZ)
    AND A
    JR NZ, .ESPERAR_HAZ
    ; Tic que llego tarde: con tan pocas filas rapidas las ultimas se
    ; cortarian. Se vuelca en el frame siguiente, ya con todas.
.OTRO_FRAME:
    CALL HAZ_PASADO
    LD A, (ULTIMO_FLANCO)
    LD HL, CONTADOR_FRAMES
    CP (HL)
    JR Z, .OTRO_FRAME
    LD A, (HL)
    LD (ULTIMO_FLANCO), A
.ESPERAR_HAZ:
    CALL HAZ_PASADO
    JR NZ, .HAZ_O_VBLANK
    LD A, (ULTIMO_FLANCO)
    LD HL, CONTADOR_FRAMES
    CP (HL)
    JR Z, .ESPERAR_HAZ
    JR .VOLCAR                  ; otro VBLANK sin marca: se vuelca sin sincronizar
.HAZ_LLEGO:
    LD A, (FILAS_MINIMAS)
    LD C, A
    LD A, (FILAS_TRASPUESTAS)
    CP C
    JR NC, .HAZ_EN_MARCA
    XOR A                       ; no bastan: se acaba de trasponer sin
    LD (VIGILAR_HAZ), A         ; mirar el haz (repite la fila cortada)
    JR .SIGUIENTE_TRASPUESTA
.HAZ_O_VBLANK:
    LD A, (ULTIMO_FLANCO)
    LD HL, CONTADOR_FRAMES
    CP (HL)
    JR NZ, .VOLCAR              ; era un VBLANK, no la marca
.HAZ_EN_MARCA:
    LD A, 1
    LD (SINCRONIZADO), A

    ; --- volcado: filas lentas salvo las traspuestas tras el VBLANK ---
.VOLCAR:
    XOR A
    LD (FILAS_RAPIDAS_RESTANTES), A
    LD (SEMIRRAPIDA), A
    INC A
    LD (VOLCANDO), A            ; la ISR aplaza la musica
    LD HL, BUFFER_LOSETAS_TRABAJO
    LD DE, ZONA_PATRON_VRAM_LABERINTO
    LD B, 18
.FILA:
    LD A, B
    CP 18 - FILA_RAPIDA
    CALL Z, DECIDIR_FILAS_RAPIDAS
    DI
    LD A, E
    OUT ($99), A
    LD A, D
    OR $40
    OUT ($99), A
    LD C, $98
    LD A, (FILAS_RAPIDAS_RESTANTES)
    AND A
    JR Z, .NO_RAPIDA
    DEC A
    LD (FILAS_RAPIDAS_RESTANTES), A
    PUSH HL
    PUSH BC
    LD HL, (PUNTERO_TRASPUESTA)
    CALL VOLCAR_FILA_RAPIDA     ; deja HL en la fila traspuesta siguiente
    LD (PUNTERO_TRASPUESTA), HL
    POP BC
    POP HL
    JR .FILA_HECHA
.NO_RAPIDA:
    LD A, (SEMIRRAPIDA)
    AND A
    JR Z, .LENTA
    XOR A
    LD (SEMIRRAPIDA), A
    PUSH BC
    CALL VOLCAR_FILA_SEMIRRAPIDA
    POP BC
    JR .FILA_HECHA
.LENTA:
    EX (SP), HL                 ; retardo tras fijar la direccion, como SETVRAM
    EX (SP), HL
    CALL VOLCAR_FILA_CARACTERES
.FILA_HECHA:
    EI                          ; aqui entra la VBLANK pendiente
    INC H
    INC D
    DJNZ .FILA
    XOR A
    LD (VOLCANDO), A
    ; --- musica aplazada: un paso por cada VBLANK del volcado ---
.MUSICA:
    LD HL, MUSICA_PENDIENTE
    LD A, (HL)
    AND A
    RET Z
    DEC (HL)
    DI
    CALL DESPACHAR_EFECTO_SONIDO
    EI
    JR .MUSICA

; Al empezar la fila 7: rapidas solo si el volcado empezo sincronizado
; y el VBLANK ya ha llegado (durante la fila 6). Asi las filas rapidas
; caen siempre dentro del borde. Conserva BC, DE y HL.
DECIDIR_FILAS_RAPIDAS:
    LD A, (SINCRONIZADO)
    AND A
    RET Z
    PUSH HL
    LD A, (ULTIMO_FLANCO)
    LD HL, CONTADOR_FRAMES
    CP (HL)
    LD HL, TRASPUESTA
    LD (PUNTERO_TRASPUESTA), HL
    POP HL
    RET Z                       ; aun no hubo VBLANK: todo lento
    LD A, (FILAS_TRASPUESTAS)
    LD (FILAS_RAPIDAS_RESTANTES), A
    ; A 50 Hz con una traspuesta de menos, a la ultima rapida le sigue
    ; una semirrapida, que aun acaba dentro del borde.
    CP FILAS_RAPIDAS_50HZ - 1
    RET NZ
    LD A, (TIC_FRAMES)
    CP 6
    RET NC
    LD A, 1
    LD (SEMIRRAPIDA), A
    RET

; --------------------------------------------------------------
;  DESPACHAR_SONIDO_OPT: lo llama la ISR en lugar de
;  DESPACHAR_EFECTO_SONIDO. Durante el volcado solo apunta el paso.
; --------------------------------------------------------------
DESPACHAR_SONIDO_OPT:
    LD A, (VOLCANDO)
    AND A
    JP Z, DESPACHAR_EFECTO_SONIDO
    LD HL, MUSICA_PENDIENTE
    INC (HL)
    RET

; --------------------------------------------------------------
;  HAZ_PASADO: NZ si el haz ya ha pasado la marca en este frame (o si
;  la lectura del estado se ha encontrado un VBLANK, que se atiende
;  aqui mismo para que no se pierda). Solo cambia AF.
; --------------------------------------------------------------
HAZ_PASADO:
    DI
    IN A, ($99)
    OR A
    JP P, .SIN_VBLANK
    CALL ATENDER_VBLANK_ROBADO
    OR A                        ; A conserva el bit 7: NZ
    RET
.SIN_VBLANK:
    EI
    AND $40                     ; quinto sprite: el haz llego a la linea 25
    RET

; Leer el estado borra el aviso de VBLANK y la ISR ya no entraria:
; se ejecuta su cuerpo como si hubiera entrado (vuelve con EI).
ATENDER_VBLANK_ROBADO:
    PUSH AF
    JP ENTRADA_INTERRUPCION_VBLANK.ATENDER

; --------------------------------------------------------------
;  ESCRIBIR_MARCA_HAZ: sprites 0-4 en la linea 25, transparentes y
;  sin solaparse (sin colision); el 5 corta la lista. 41 ciclos por
;  byte: vale tambien en pantalla activa.
; --------------------------------------------------------------
ESCRIBIR_MARCA_HAZ:
    DI
    LD HL, ATRIBUTOS_SPRITES
    CALL SETVRAM
    LD HL, .ATRIBUTOS
    LD B, .FIN - .ATRIBUTOS
.BYTE:
    LD A, (HL)
    OUT ($98), A
    INC HL
    DJNZ .BYTE
    EI
    RET
.ATRIBUTOS:
    DB Y_MARCA_HAZ, 0, 0, 0
    DB Y_MARCA_HAZ, 48, 0, 0
    DB Y_MARCA_HAZ, 96, 0, 0
    DB Y_MARCA_HAZ, 144, 0, 0
    DB Y_MARCA_HAZ, 192, 0, 0
    DB $D0
.FIN:

; --------------------------------------------------------------
;  TRASPONER_FILA: copia la fila H del buffer a DE (pagina alineada)
;  en el orden de la tabla de patrones: byte (c, y) a DE + 8c + y.
;  26 ciclos por byte. Con VIGILAR_HAZ, cada 2 caracteres mira si el
;  haz ya ha llegado a la marca: entonces vuelve con CF=1 (fila sin
;  terminar). Solo se vigila despues del VBLANK y antes de la linea
;  25, cuando leer el estado no puede tropezar con un VBLANK.
; --------------------------------------------------------------
TRASPONER_FILA:
.C = 0
    DUP 24
.Y = 0
    DUP 8
    LD L, $04 + .C + 32 * .Y
    LDI
.Y = .Y + 1
    EDUP
    IF (.C & 1) == 1
    LD A, (VIGILAR_HAZ)
    AND A
    JR Z, $ + 9                 ; antes del VBLANK no se mira
    IN A, ($99)
    AND $40
    JP NZ, .HAZ
    ENDIF
.C = .C + 1
    EDUP
    OR A
    RET
.HAZ:
    SCF
    RET

; --------------------------------------------------------------
;  TRASPONER_ANTES: la llama ESPERAR_TIC cuando el juego termina el tic
;  antes del VBLANK objetivo. La CPU iba a esperar de todos modos, asi
;  que traspone ya todas las filas rapidas y el volcado no tiene que
;  hacerlo con prisa entre el VBLANK y la linea 25. Conserva BC, DE, HL.
; --------------------------------------------------------------
TRASPONER_ANTES:
    PUSH BC
    PUSH DE
    PUSH HL
    XOR A
    LD (VIGILAR_HAZ), A
    CALL NUMERO_FILAS_RAPIDAS
    LD A, B
    LD (FILAS_TRASPUESTAS), A
    LD H, HIGH (BUFFER_LOSETAS_TRABAJO + FILA_RAPIDA * 256)
    LD DE, TRASPUESTA
.FILA:
    PUSH BC
    PUSH HL
    PUSH DE
    CALL TRASPONER_FILA
    POP DE
    POP HL
    POP BC
    INC H
    LD A, E                     ; siguiente fila traspuesta: +192
    ADD A, 192
    LD E, A
    JR NC, $ + 3
    INC D
    DJNZ .FILA
    LD A, 1
    LD (YA_TRASPUESTAS), A
    POP HL
    POP DE
    POP BC
    RET

; B = filas rapidas que caben en el borde; FILAS_TRASPUESTAS = 0
NUMERO_FILAS_RAPIDAS:
    XOR A
    LD (FILAS_TRASPUESTAS), A
    LD A, (TIC_FRAMES)
    CP 6
    LD B, FILAS_RAPIDAS_50HZ
    LD A, FILAS_RAPIDAS_50HZ - 1 ; con 4 aun cabe (3 lineas de margen)
    JR C, .FIN
    LD B, FILAS_RAPIDAS_60HZ
    LD A, FILAS_RAPIDAS_60HZ
.FIN:
    LD (FILAS_MINIMAS), A
    RET

; --------------------------------------------------------------
;  VOLCAR_FILA_RAPIDA: 192 bytes seguidos desde HL al puerto C.
;  Solo fuera de la pantalla activa (18 ciclos por byte).
; --------------------------------------------------------------
VOLCAR_FILA_RAPIDA:
    DUP 192
    OUTI
    EDUP
    RET

;  VOLCAR_FILA_SEMIRRAPIDA: fila sin trasponer, directa del buffer
;  (L = $04 + c + 32*y) a 26 ciclos por byte. Solo en el borde: en
;  pantalla activa el TMS9918 necesita 29.
VOLCAR_FILA_SEMIRRAPIDA:
.C = 0
    DUP 24
.Y = 0
    DUP 8
    LD L, $04 + .C + 32 * .Y
    OUTI
.Y = .Y + 1
    EDUP
.C = .C + 1
    EDUP
    RET

VOLCANDO:                   DB 0
VIGILAR_HAZ:                DB 0
YA_TRASPUESTAS:             DB 0
MUSICA_PENDIENTE:           DB 0
SINCRONIZADO:               DB 0
FILAS_TRASPUESTAS:          DB 0
FILAS_MINIMAS:              DB 0
FILAS_RAPIDAS_RESTANTES:    DB 0
PUNTERO_TRASPUESTA:         DW 0
SEMIRRAPIDA:                DB 0

FIN_VOLCADO_HAZ:

    ASSERT FIN_VOLCADO_HAZ <= SOMBRA_MATRIZ

; Filas traspuestas (192 bytes cada una, seguidas), solo en ejecucion.
; Detras de SOMBRA_MATRIZ queda libre hasta MADMIX1.BIN ($83F9).
TRASPUESTA:                 EQU SOMBRA_MATRIZ + 928
    ASSERT TRASPUESTA + FILAS_RAPIDAS_50HZ * 192 <= $83F9
