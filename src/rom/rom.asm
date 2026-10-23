; ==============================================================
;  rom.asm -- Mad Mix Game v9990: cartucho megaROM ASCII16 (MSX1)
;
;  Banco 0 ($4000-$7FFF): cabecera "AB" + cargador.
;  Bancos 1..n: carga util (imagen RAM del juego y logo), troceada
;  por tools/build.py en fragmentos de <=2 KB que nunca cruzan un
;  limite de banco, descritos en build/tabla_carga.inc.
;
;  El juego original corre ENTERO en RAM (las 4 paginas, sin BIOS:
;  parchea $0038 y accede al VDP/PSG/PPI por puertos), asi que el
;  cartucho solo sirve de soporte: el cargador copia cada tramo a su
;  direccion nativa, deja las 4 paginas en RAM y salta a START
;  ($8400), igual que hacia LOAD.BIN tras leer la cinta.
;
;  Mapa durante la carga:
;    $E000-$E7FF  CARGADOR_RAM (este codigo, copiado desde el banco 0)
;    $E800-$EFFF  BUFFER de 2 KB para los fragmentos
;    $F300        pila del cargador (bajo la zona de trabajo del BIOS)
;  Nada de esto choca con la imagen del juego ($1000-$64FF,
;  $8400-$DDA0) ni con el logo ($9470-$A50D).
;
;  Requisitos: MSX1 con 64 KB de RAM (como el original). La RAM de
;  las paginas 0-2 se toma del mismo slot/subslot que la pagina 3
;  (lo normal en un MSX1 de 64 KB) y se comprueba antes de usarla.
; ==============================================================

EXPTBL      EQU $FCC1
SLTTBL      EQU $FCC5
CLIKSW      EQU $F3DB
FORCLR      EQU $F3E9
BAKCLR      EQU $F3EA
BDRCLR      EQU $F3EB
ENASLT      EQU $0024
CHGCLR      EQU $0062
INIGRP      EQU $0072
CHPUT       EQU $00A2
INITXT      EQU $006C
CHGCPU      EQU $0180

BANCO1_REG  EQU $6000           ; ASCII16: banco de la pagina 1
CARGADOR_RAM EQU $E000
BUFFER      EQU $E800
PILA        EQU $F300

ENTRADA_JUEGO EQU $8400         ; START del motor
TIC_FRAMES    EQU $6500         ; optimizaciones.asm: frames por tic del bucle principal
V9_INICIAR    EQU $6C00         ; v9990.asm: detecta e inicia el V9990 (GFX9000)
JIFFY         EQU $FC9E
ENTRADA_LOGO  EQU $9470         ; ENTRADA_LOGOTOPO

INICIO_CARGA EQU $5800         ; tools/build.py: INICIO_CARGA
    OUTPUT "../../build/madmix_v9990.rom"

    ORG $4000
CABECERA_ROM:
    DB "AB"
    DW INICIO_ROM
    DW 0, 0, 0
    DS 6, 0

; --------------------------------------------------------------
INICIO_ROM:
    DI
    LD SP, PILA

    ; --- slot de este cartucho (pagina 1) ---
    IN A, ($A8)
    RRCA
    RRCA
    AND 3
    LD C, A
    LD B, 0
    LD HL, EXPTBL
    ADD HL, BC
    LD A, (HL)
    AND $80
    JR Z, .ROM_NO_EXPANDIDO
    OR C
    LD C, A                     ; C = $80 | primario
    AND 3
    LD E, A
    LD D, 0
    LD HL, SLTTBL
    ADD HL, DE
    LD A, (HL)                  ; registro de subslot actual de ese primario
    AND $0C                     ; subslot de la pagina 1
    OR C
    LD C, A
.ROM_NO_EXPANDIDO:
    LD A, C
    LD (SLOT_ROM_TMP), A

    ; --- slot de la RAM de la pagina 3 ---
    IN A, ($A8)
    RLCA
    RLCA
    AND 3
    LD C, A
    LD B, 0
    LD HL, EXPTBL
    ADD HL, BC
    LD A, (HL)
    AND $80
    JR Z, .RAM_NO_EXPANDIDA
    OR C
    LD C, A
    LD A, ($FFFF)
    CPL
    AND $C0                     ; subslot de la pagina 3 (bits 6-7)
    RRCA
    RRCA
    RRCA
    RRCA                        ; -> bits 2-3
    OR C
    LD C, A
.RAM_NO_EXPANDIDA:
    LD A, C
    LD (SLOT_RAM_TMP), A

    ; --- copia el cargador a RAM (pagina 3) ---
    LD HL, CARGADOR_ORIGEN
    LD DE, CARGADOR_RAM
    LD BC, CARGADOR_FIN - CARGADOR_ORIGEN
    LDIR
    LD A, (SLOT_ROM_TMP)
    LD (SLOT_ROM), A
    LD A, (SLOT_RAM_TMP)
    LD (SLOT_RAM), A

    ; --- pagina 2 = RAM (via BIOS: seguro desde la pagina 1) ---
    LD A, (SLOT_RAM)
    LD H, $80
    CALL ENASLT
    DI

    ; --- comprueba que hay RAM en las paginas 0-2 de ese slot ---
    CALL COMPROBAR_RAM
    JP C, ERROR_SIN_RAM

    ; --- pantalla como dejaba el BASIC de cinta: COLOR 1,1,1:SCREEN 2 ---
    XOR A
    LD (CLIKSW), A
    LD A, 1
    LD (FORCLR), A
    LD (BAKCLR), A
    LD (BDRCLR), A
    CALL CHGCLR
    CALL INIGRP
    DI

    ; --- 50 o 60 Hz: fija el ritmo del juego (5 o 6 frames por tic) ---
    CALL DETECTAR_FRECUENCIA
    LD (TIC_DETECTADO), A

    ; --- turbo R: al R800 (modo ROM, con el piloto), despues de medir la
    ; frecuencia, que cuenta vueltas de un bucle (f2j) ---
    LD A, ($002D)               ; version del MSX: 3 = turbo R
    CP 3
    JR C, .SIN_R800
    LD A, $81
    CALL CHGCPU
    DI
.SIN_R800:

    ; --- con GFX9000: el TMS muestra la pantalla de carga y el logo va al V9990 ---
    CALL V9_LOGO_PREPARAR

    ; --- logo de Topo Soft (version de cinta), con BIOS presente ---
    LD IX, TABLA_LOGO
    CALL COPIAR_FRAGMENTOS
    CALL LOGO_COPIAS            ; con GFX9000: copias de las tablas del TMS para el logo
    CALL LOGO_GANCHO_PONER
    EI
    CALL ENTRADA_LOGO
    DI
    CALL LOGO_GANCHO_QUITAR

    ; --- graficos del V9990 (GFX9000), si lo hay: con la ROM aun visible ---
    CALL V9_SUBIR

    ; --- juego: a partir de aqui ya no hay BIOS ---
    JP ARRANCAR_JUEGO

; --------------------------------------------------------------
;  DETECTAR_FRECUENCIA: mide cuantas vueltas de un bucle fijo caben
;  en 4 interrupciones del BIOS. 60 Hz: 4 frames = ~239 000 ciclos;
;  50 Hz: ~286 000. Con 39 ciclos por vuelta salen ~6100 y ~7300
;  vueltas (menos lo que tarde la ISR del BIOS); el corte esta en
;  6700. No depende del byte $002B, que algunos MSX traen mal.
;  Devuelve A = frames por tic: 6 (60 Hz) o 5 (50 Hz).
; --------------------------------------------------------------
DETECTAR_FRECUENCIA:
    EI
    HALT                        ; empieza justo tras una interrupcion
    LD A, (JIFFY)
    ADD A, 4
    LD B, A
    LD DE, 0
.CONTAR:
    INC DE                      ; 7
    LD A, (JIFFY)               ; 14
    CP B                        ; 5
    JR NZ, .CONTAR              ; 13
    DI
    LD HL, 6700
    AND A
    SBC HL, DE                  ; CF=1 si DE > 6700 -> 50 Hz
    LD A, 6
    RET NC
    DEC A
    RET

; --------------------------------------------------------------
;  V9_LOGO_PREPARAR: si hay un V9990, lo pone en modo P1 como espejo
;  de la pantalla del TMS (paleta del TMS, capa A = patron fila*32 +
;  columna, ver LOGO_WRTVRM_V9) para que el logo de Topo salga por el
;  GFX9000, y pone en el TMS la pantalla de carga original (la portada
;  de MADMIX.SCR). En un MSX2 la pantalla de carga va a la VRAM alta
;  ($10000) y el VDP la muestra desde alli todo el tiempo, porque el
;  juego sigue usando $0000-$3FFF (el espejo de los menus la lee) y
;  solo escribe los registros 1 y 7. En un MSX1 el TMS solo tiene
;  16 KB: la pantalla de carga se ve hasta que el juego dibuja encima.
; --------------------------------------------------------------
V9_LOGO_PREPARAR:
    LD A, 15
    OUT ($64), A
    LD A, $2A
    OUT ($63), A
    LD A, $4F
    OUT ($64), A
    IN A, ($63)
    CP $2A
    RET NZ
    LD A, 15
    OUT ($64), A
    LD A, $15
    OUT ($63), A
    LD A, $4F
    OUT ($64), A
    IN A, ($63)
    CP $15
    RET NZ
    LD A, 1
    LD (LOGO_EN_V9990), A
    LD A, 2
    OUT ($67), A                ; reinicio
    XOR A
    OUT ($67), A
    LD HL, V9L_REGISTROS
.REGISTROS:
    LD A, (HL)
    INC HL
    CP $FF
    JR Z, .PAL
    OUT ($64), A
    LD A, (HL)
    INC HL
    OUT ($63), A
    JR .REGISTROS
.PAL:
    LD A, 7
    OUT ($64), A
    LD A, (TIC_DETECTADO)
    CP 5
    LD A, 0
    JR NZ, .NTSC
    LD A, $08
.NTSC:
    OUT ($63), A
    ; paleta 0-15 = colores del TMS
    LD A, 14
    OUT ($64), A
    XOR A
    OUT ($63), A
    LD HL, V9L_PALETA_TMS
    LD BC, 48 * 256 + $61
    OTIR
    ; espejo transparente, patron 768 negro, patron 0 de la capa B
    ; transparente y nombres de la capa B a 0
    LD IX, V9L_RELLENOS
.RELLENO:
    LD A, (IX+0)
    CP $FF
    JR Z, .NOMBRES
    XOR A
    OUT ($64), A
    LD A, (IX+1)
    OUT ($63), A
    LD A, (IX+2)
    OUT ($63), A
    LD A, (IX+0)
    OUT ($63), A
    LD C, (IX+3)
    LD B, (IX+4)
    LD A, (IX+5)
    ; bytes multiplo de 256: B vueltas de 256 OUT
    LD E, B
    LD B, 0
.BYTE:
    OUT ($60), A
    DJNZ .BYTE
    DEC E
    JR NZ, .BYTE
    LD DE, 6
    ADD IX, DE
    JR .RELLENO
.NOMBRES:
    ; capa A ($7C000, 64 nombres por fila): filas 1-24 = filas 0-23 del
    ; TMS (patron fila*32 + columna), el resto el patron negro 768
    XOR A
    OUT ($64), A
    OUT ($63), A
    LD A, $C0
    OUT ($63), A
    LD A, 7
    OUT ($63), A
    LD DE, 0                    ; siguiente patron del espejo
    LD B, 27
.FILA:
    LD C, 64
    LD A, B
    CP 27
    JR Z, .NEGRA
    CP 3
    JR C, .NEGRA
    LD C, 32
.ESPEJO:
    LD A, E
    OUT ($60), A
    LD A, D
    OUT ($60), A
    INC DE
    DEC C
    JR NZ, .ESPEJO
    LD C, 32
.NEGRA:
    LD A, 0                     ; 768 = $0300
    OUT ($60), A
    LD A, 3
    OUT ($60), A
    DEC C
    JR NZ, .NEGRA
    DJNZ .FILA
    LD A, 8
    OUT ($64), A
    LD A, $C2                   ; pantalla encendida, sin sprites
    OUT ($63), A

    ; --- pantalla de carga en el TMS ---
    LD IX, TABLA_PORTADA_TMS
    CALL COPIAR_FRAGMENTOS
    LD BC, $A201                ; R#1: pantalla apagada mientras se copia
    CALL V9L_VDP_REG
    LD A, ($002D)
    AND A
    JR Z, .MSX1
    LD BC, $040E                ; R#14 = 4: VRAM $10000-$13FFF
    CALL V9L_VDP_REG
.MSX1:
    LD HL, PORTADA_PATRON_RAM
    LD DE, $0000
    LD BC, 6144
    CALL V9L_VDP_COPIAR
    ; nombres: identidad
    LD A, $00
    OUT ($99), A
    LD A, $18 | $40
    OUT ($99), A
    LD BC, 768
    LD E, 0
.NOMBRE:
    LD A, E
    OUT ($98), A
    INC E
    DEC BC
    LD A, B
    OR C
    JR NZ, .NOMBRE
    ; color: cada byte de PORTADA_COLOR da las 8 lineas de una celda, con
    ; la misma descompresion que DIBUJAR_PORTADA
    LD A, $00
    OUT ($99), A
    LD A, $20 | $40
    OUT ($99), A
    LD HL, PORTADA_COLOR_RAM
    LD BC, 768
.CELDA:
    PUSH BC
    LD A, (HL)
    INC HL
    AND A
    JR Z, .COLOR
    LD B, A
    AND $07
    LD C, A                     ; indice 1
    LD A, B
    AND $78
    RRCA
    RRCA
    RRCA
    LD B, A                     ; l
    AND $08
    OR C
    LD C, A                     ; indice 2 = (l and 8) or indice 1
    PUSH HL
    LD HL, PORTADA_PALETA_RAM
    LD A, L
    ADD A, B
    LD L, A
    LD B, (HL)                  ; nibble bajo = paleta[l]
    LD HL, PORTADA_PALETA_RAM
    LD A, L
    ADD A, C
    LD L, A
    LD A, (HL)
    RRCA
    RRCA
    RRCA
    RRCA
    OR B                        ; nibble alto = paleta[indice 2]
    POP HL
.COLOR:
    LD B, 8
.LINEA:
    OUT ($98), A
    NOP
    DJNZ .LINEA
    POP BC
    DEC BC
    LD A, B
    OR C
    JR NZ, .CELDA
    LD A, ($002D)
    AND A
    JR Z, .ENCENDER
    LD HL, V9L_REGISTROS_MSX2
.MSX2:
    LD C, (HL)
    INC HL
    LD B, (HL)
    INC HL
    BIT 7, C
    JR NZ, .ENCENDER
    CALL V9L_VDP_REG
    JR .MSX2
.ENCENDER:
    LD BC, $0107                ; R#7: borde negro, como la portada
    CALL V9L_VDP_REG
    LD BC, $E201                ; R#1: pantalla encendida
    JP V9L_VDP_REG

; LOGO_COPIAS: copias de las tablas del TMS como si estuviera recien
; borrado (patrones 0, color $F0: el relleno con que empieza el logo,
; asi no hay que redibujar nada al borrar; se ve igual, negro) y la
; tabla LOGO_DIR (direccion en el V9990 de cada celda). Despues de la
; pantalla de carga, que usa la misma RAM.
LOGO_COPIAS:
    LD A, (LOGO_EN_V9990)
    AND A
    RET Z
    LD HL, LOGO_PATRONES
    LD BC, 6144
    XOR A
    CALL .RELLENAR
    LD HL, $8000
    LD BC, 20 * 256
    LD A, $F0
    CALL .RELLENAR
    LD HL, $D800
    LD BC, 4 * 256
    LD A, $F0
    CALL .RELLENAR
    ; LOGO_DIR: byte bajo de la direccion del V9990 y linea / 2, por
    ; el byte bajo de la del TMS
    LD HL, LOGO_DIR
.D:
    LD A, L
    RRCA
    LD C, A
    AND $7C                     ; columna*4
    LD B, A
    LD A, C
    AND $80                     ; (linea and 1)*128
    OR B
    LD (HL), A
    INC H
    LD A, L
    AND 6
    RRCA
    LD (HL), A
    DEC H
    INC L
    JR NZ, .D
    ; LOGO_M: pixel a $F si su bit esta a 1
    LD HL, LOGO_M
.M:
    LD C, L
    LD B, 4
    PUSH HL
.M_BYTE:
    XOR A
    RL C
    JR NC, $ + 4
    OR $F0
    RL C
    JR NC, $ + 4
    OR $0F
    LD (HL), A
    INC H
    DJNZ .M_BYTE
    POP HL
    INC L
    JR NZ, .M
    ; LOGO_FONDO y LOGO_DIF
    LD HL, LOGO_FONDO
.C:
    LD A, L
    AND $0F
    LD C, A
    RLCA
    RLCA
    RLCA
    RLCA
    OR C
    LD (HL), A
    LD A, L
    RRCA
    RRCA
    RRCA
    RRCA
    AND $0F
    XOR C
    LD B, A
    RLCA
    RLCA
    RLCA
    RLCA
    OR B
    INC H
    LD (HL), A
    DEC H
    INC L
    JR NZ, .C
    RET
.RELLENAR:
    LD (HL), A
    LD D, H
    LD E, L
    INC DE
    DEC BC
    LDIR
    RET

; B = valor, C = registro del VDP del MSX
V9L_VDP_REG:
    LD A, B
    OUT ($99), A
    LD A, C
    OR $80
    OUT ($99), A
    RET

; HL = origen, DE = direccion de VRAM (14 bits), BC = bytes
V9L_VDP_COPIAR:
    LD A, E
    OUT ($99), A
    LD A, D
    OR $40
    OUT ($99), A
.BYTE:
    LD A, (HL)
    OUT ($98), A
    INC HL
    DEC BC
    LD A, B
    OR C
    JR NZ, .BYTE
    RET

; Registros del V9990 para el logo (sin interrupciones del V9990)
V9L_REGISTROS:
    DB 6, $05                   ; P1
    DB 8, $02                   ; pantalla apagada mientras se prepara
    DB 9, 0                     ; sin interrupciones
    DB 13, $04                  ; capa A con la paleta 0-15
    DB 15, 0                    ; fondo = entrada 0 (negro)
    DB $FF

; Rellenos: DB bits 16-18 : DW direccion : DW bytes : DB valor
V9L_RELLENOS:
    DB 0 : DW $0000, $6000 : DB $00     ; espejo ($00000-$05FFF) transparente (fondo negro)
    DB 0 : DW $6000, $0400 : DB $11     ; patron 768 (linea 192) en negro
    DB 4 : DW $0000, $0400 : DB $00     ; patron 0 de la capa B ($40000)
    DB 7 : DW $E000, $2000 : DB $00     ; nombres de la capa B
    DB $FF

; MSX2: la pantalla de carga en $10000 (patrones), $11800 (nombres) y
; $12000 (color); sprites apagados. DB registro, valor; $80 termina.
V9L_REGISTROS_MSX2:
    DB 14, 0                    ; el juego escribe en $0000-$3FFF
    DB 2, $46                   ; nombres en $11800
    DB 3, $FF                   ; color en $12000 (con R#10)
    DB 10, $04
    DB 4, $23                   ; patrones en $10000
    DB 8, $0A                   ; sin sprites
    DB $80

V9L_PALETA_TMS:
    DB  0,  0,  0,   0,  0,  0,   4, 25,  8,  11, 27, 15
    DB 10, 10, 29,  15, 14, 31,  26, 10,  9,   8, 29, 30
    DB 31, 10, 10,  31, 15, 15,  26, 24, 10,  28, 25, 16
    DB  4, 22,  7,  25, 11, 23,  25, 25, 25,  31, 31, 31

; Pantalla de carga en RAM (TABLA_PORTADA_TMS, build.py)
PORTADA_PALETA_RAM EQU $A5F0
PORTADA_PATRON_RAM EQU $A600
PORTADA_COLOR_RAM  EQU $BE00

; --------------------------------------------------------------
ERROR_SIN_RAM:
    CALL INITXT
    LD HL, TEXTO_SIN_RAM
.BUCLE:
    LD A, (HL)
    AND A
.FIN:
    JR Z, .FIN
    CALL CHPUT
    INC HL
    JR .BUCLE

TEXTO_SIN_RAM:
    DB "Mad Mix Game necesita 64 KB de RAM", 0

SLOT_ROM_TMP: EQU $F2F0         ; temporales antes de copiar el cargador
SLOT_RAM_TMP: EQU $F2F1

; ==============================================================
;  Codigo que se ejecuta en RAM (pagina 3), copiado a $E000.
; ==============================================================
CARGADOR_ORIGEN:
    DISP CARGADOR_RAM

; Entradas fijas que usa el logo de Topo (logotopo_cm_body.asm)
;  (sin GFX9000 van al BIOS; LOGO_GANCHO_PONER las cambia)
    ASSERT $ == $E000
    JP $004D
    ASSERT $ == $E003
    JP $0059

SLOT_ROM:   DB 0
SLOT_RAM:   DB 0
TIC_DETECTADO: DB 6
LOGO_EN_V9990: DB 0             ; 1: el logo se dibuja en el V9990

; --------------------------------------------------------------
;  Logo de Topo en el V9990. LOGO_WRTVRM_V9 (WRTVRM del logo: A = byte,
;  HL = direccion del TMS; conserva todos los registros) no toca el
;  TMS: guarda el byte en una copia de las tablas de patrones y color
;  en RAM y, si ha cambiado, dibuja esa linea de la celda en el espejo
;  de la capa A del V9990 ($00000, patron fila*32 + columna).
;
;  RAM libre durante el logo (el logo ocupa $9470-$A50D y usa
;  $C000-$D7FF como copia de los patrones, ver LOGO_LDIRMV_V9):
;    $A600-$BDFF  copia de los patrones del TMS
;    $8000-$93FF  copia del color, filas 0-19; $D800-$DBFF filas 20-23
;    $DC00-$DFFF, $E800-$E9FF y $EE00-$EFFF  tablas de LOGO_WRTVRM_V9
;  (el BUFFER de COPIAR_FRAGMENTOS no se usa mientras corre el logo)
; --------------------------------------------------------------
LOGO_PATRONES   EQU $A600
LOGO_DIR        EQU $E800       ; 2 paginas: byte bajo y linea / 2 (ver LOGO_COPIAS)
LOGO_M          EQU $DC00       ; 4 paginas: byte k (2 pixeles) del patron p, $F/$0 por pixel
LOGO_FONDO      EQU $EE00       ; color c del TMS: fondo * $11
LOGO_DIF        EQU $EF00       ; color c: (tinta xor fondo) * $11

LOGO_WRTVRM_V9:
    PUSH HL
    EXX                         ; el logo no usa los registros alternativos
    POP HL                      ; HL' = direccion del TMS
    LD C, A
    LD A, H
    CP $18
    JR C, .PATRON
    SUB $20
    JR C, .NADA                 ; nombres: identidad, como deja INIGRP
    CP 24
    JR NC, .NADA                ; sprites: no se usan
    LD B, A                     ; fila
    CP 20
    JR C, .COLOR_BAJO
    ADD A, $D8 - $80 - 20
.COLOR_BAJO:
    ADD A, $80
    LD H, A
    LD A, (HL)
    CP C
    JR Z, .NADA
    LD (HL), C
    LD A, B
    ADD A, HIGH LOGO_PATRONES
    LD H, A
    LD E, (HL)                  ; patron
    LD A, C                     ; color
    JR .DIBUJAR
.PATRON:
    LD B, A                     ; fila
    ADD A, HIGH LOGO_PATRONES
    LD H, A
    LD A, (HL)
    CP C
    JR Z, .NADA
    LD (HL), C
    LD E, C                     ; patron
    LD A, B
    CP 20
    JR C, .COLOR_ALTO
    ADD A, $D8 - $80 - 20
.COLOR_ALTO:
    ADD A, $80
    LD H, A
    LD A, (HL)                  ; color
    ; esa linea de la celda, ya al V9990 (f2l: antes se marcaba la celda y
    ; se redibujaba en las pausas, pero el logo dibuja casi todo sin
    ; pausas y el V9990 iba muy por detras). Direccion: fila*1024 +
    ; linea*128 + columna*4; byte k = fondo xor (M[k][patron] and
    ; (tinta xor fondo))
.DIBUJAR:
    LD D, A
    XOR A
    OUT ($64), A                ; R#0, con autoincremento
    LD H, HIGH LOGO_DIR
    LD A, (HL)
    OUT ($63), A
    INC H
    LD A, B
    ADD A, A
    ADD A, A
    OR (HL)
    OUT ($63), A
    XOR A
    OUT ($63), A
    LD L, D
    LD H, HIGH LOGO_FONDO
    LD D, (HL)
    INC H
    LD B, (HL)                  ; LOGO_DIF
    LD L, E
    LD H, HIGH LOGO_M
    LD A, (HL)
    AND B
    XOR D
    OUT ($60), A
    INC H
    LD A, (HL)
    AND B
    XOR D
    OUT ($60), A
    INC H
    LD A, (HL)
    AND B
    XOR D
    OUT ($60), A
    INC H
    LD A, (HL)
    AND B
    XOR D
    OUT ($60), A
.NADA:
    LD A, C
    EXX
    RET

; --------------------------------------------------------------
;  LOGO_LDIRMV_V9: LDIRMV del logo (HL = VRAM, DE = RAM, BC = bytes;
;  el logo solo lee la tabla de patrones). Con GFX9000 lee la copia.
; --------------------------------------------------------------
LOGO_LDIRMV_V9:
    LD A, H
    ADD A, HIGH LOGO_PATRONES
    LD H, A
    LDIR
    RET


; Con GFX9000: el logo escribe y lee en las copias (ver
; logotopo_cm_body.asm). Sin GFX9000 no cambia nada.
LOGO_GANCHO_PONER:
    LD A, (LOGO_EN_V9990)
    AND A
    RET Z
    LD HL, LOGO_WRTVRM_V9
    LD ($E001), HL
    LD HL, LOGO_LDIRMV_V9
    LD ($E004), HL
    RET

; Deja de usar el V9990
LOGO_GANCHO_QUITAR:
    LD A, (LOGO_EN_V9990)
    AND A
    RET Z
    LD HL, $004D
    LD ($E001), HL
    LD HL, $0059
    LD ($E004), HL
    XOR A
    LD (LOGO_EN_V9990), A
    RET

; --------------------------------------------------------------
;  PONER_SLOT: conmuta la pagina B (0-2) al slot A (formato
;  E000SSPP). Se ejecuta desde la pagina 3 con interrupciones
;  cerradas. Si el slot esta expandido y su primario es el de la
;  pagina 3, ajusta tambien el registro de subslot ($FFFF); si el
;  primario es otro, su subslot ya quedo fijado por el BIOS al
;  arrancar (caso del propio cartucho en la pagina 1).
; --------------------------------------------------------------
PONER_SLOT:
    PUSH BC
    PUSH DE
    PUSH HL
    LD C, A
    LD A, B
    ADD A, A
    LD E, A                     ; E = desplazamiento (2*pagina)
    LD A, C
    AND 3
    LD D, A                     ; D = primario
    BIT 7, C
    JR Z, .PRIMARIO
    IN A, ($A8)
    RLCA
    RLCA
    AND 3
    CP D
    JR NZ, .PRIMARIO
    LD A, ($FFFF)
    CPL
    LD L, A
    LD A, 3
    CALL DESPLAZAR
    CPL
    AND L
    LD L, A
    LD A, C
    RRCA
    RRCA
    AND 3
    CALL DESPLAZAR
    OR L
    LD ($FFFF), A
.PRIMARIO:
    IN A, ($A8)
    LD L, A
    LD A, 3
    CALL DESPLAZAR
    CPL
    AND L
    LD L, A
    LD A, D
    CALL DESPLAZAR
    OR L
    OUT ($A8), A
    POP HL
    POP DE
    POP BC
    RET

DESPLAZAR:                      ; A <<= E
    PUSH DE
.BUCLE:
    DEC E
    JP M, .FIN
    ADD A, A
    JR .BUCLE
.FIN:
    POP DE
    RET

; --------------------------------------------------------------
;  COMPROBAR_RAM: con la pagina 1 en ROM, pone momentaneamente las
;  paginas 0 y 2 en SLOT_RAM y verifica escritura/lectura; la pagina
;  1 se comprueba conmutandola a RAM y volviendo a la ROM. CF=1 si
;  falla. Restaura los slots originales de las paginas 0 y 1.
; --------------------------------------------------------------
COMPROBAR_RAM:
    IN A, ($A8)
    LD (.A8_ORIGINAL), A
    LD A, ($FFFF)
    CPL
    LD (.SUB_ORIGINAL), A
    LD HL, $3FFF
    LD B, 0
    CALL .PROBAR
    JR C, .FIN
    LD HL, $7FFF
    LD B, 1
    CALL .PROBAR
    JR C, .FIN
    LD HL, $BFFF
    LD B, 2
    CALL .PROBAR
.FIN:
    PUSH AF
    LD A, (SLOT_RAM)            ; el subslot solo se toco si el primario
    BIT 7, A                    ; de la RAM (= el de la pagina 3) esta
    JR Z, .SIN_SUBSLOT          ; expandido
    LD A, (.SUB_ORIGINAL)
    LD ($FFFF), A
.SIN_SUBSLOT:
    LD A, (.A8_ORIGINAL)
    OUT ($A8), A
    POP AF
    RET
.PROBAR:
    LD A, (SLOT_RAM)
    CALL PONER_SLOT
    LD A, (HL)
    LD C, A
    LD (HL), $5A
    LD A, (HL)
    CP $5A
    JR NZ, .MAL
    LD (HL), $A5
    LD A, (HL)
    CP $A5
    JR NZ, .MAL
    LD (HL), C
    AND A
    RET
.MAL:
    SCF
    RET
.A8_ORIGINAL: DB 0
.SUB_ORIGINAL: DB 0

; --------------------------------------------------------------
;  COPIAR_FRAGMENTOS: recorre una tabla (IX) de fragmentos
;    DW destino ; DB banco ; DW origen ($4000-$7FFF) ; DW longitud
;  terminada en destino = 0. Cada fragmento: banco -> pagina 1,
;  ROM -> BUFFER, pagina 1 -> RAM, BUFFER -> destino, pagina 1 ->
;  ROM. Deja el banco 0 seleccionado al terminar (se vuelve a
;  ejecutar codigo del banco 0).
; --------------------------------------------------------------
COPIAR_FRAGMENTOS:
    LD E, (IX+0)
    LD D, (IX+1)
    LD A, D
    OR E
    JR Z, .FIN
    LD A, (IX+2)
    LD (BANCO1_REG), A
    LD L, (IX+3)
    LD H, (IX+4)
    LD C, (IX+5)
    LD B, (IX+6)
    PUSH DE
    PUSH BC
    LD DE, BUFFER
    LDIR
    LD A, (SLOT_RAM)
    LD B, 1
    CALL PONER_SLOT
    POP BC
    POP DE
    LD HL, BUFFER
    LDIR
    LD A, (SLOT_ROM)
    LD B, 1
    CALL PONER_SLOT
    LD DE, 7
    ADD IX, DE
    JR COPIAR_FRAGMENTOS
.FIN:
    XOR A
    LD (BANCO1_REG), A
    RET

; --------------------------------------------------------------
;  ARRANCAR_JUEGO: paginas 0 y 2 en RAM (el BIOS desaparece), copia
;  la imagen del juego, limpia $0000-$0FFF, pagina 1 en RAM y salta
;  a START. No vuelve.
; --------------------------------------------------------------
ARRANCAR_JUEGO:
    DI
    LD A, (SLOT_RAM)
    LD B, 0
    CALL PONER_SLOT
    LD A, (SLOT_RAM)
    LD B, 2
    CALL PONER_SLOT
    LD IX, TABLA_JUEGO
    CALL COPIAR_FRAGMENTOS
    LD HL, $0000
    LD DE, $0001
    LD BC, $0FFF
    LD (HL), L
    LDIR
    LD IX, TABLA_EXT            ; V9990 con los graficos del remake ($0100-$0FFF)
    CALL COPIAR_FRAGMENTOS
    LD A, (SLOT_RAM)
    LD B, 1
    CALL PONER_SLOT
    ; con la pagina 1 ya en RAM: escribir en $6500 con la ROM visible
    ; seleccionaria un banco del mapper ASCII16 en vez de llegar a la RAM
    LD A, (TIC_DETECTADO)
    LD (TIC_FRAMES), A
    CALL V9_INICIAR             ; si hay GFX9000: modo P1 y losetas del laberinto
    JP ENTRADA_JUEGO

; --------------------------------------------------------------
;  V9_SUBIR: si hay un V9990, lo reinicia, lo pone en modo P1 con la
;  pantalla apagada y sube a su VRAM los graficos ya convertidos
;  (TABLA_V9990: DB bits 16-18 : DW bits 0-15 de la direccion de VRAM
;  : DB banco : DW origen, longitud; termina en $FF). El resto lo
;  prepara V9_INICIAR al arrancar el juego.
; --------------------------------------------------------------
V9_SUBIR:
    LD A, 15
    OUT ($64), A
    LD A, $2A
    OUT ($63), A
    LD A, $4F                   ; R#15, lectura sin autoincremento
    OUT ($64), A
    IN A, ($63)
    CP $2A
    RET NZ
    LD A, 15
    OUT ($64), A
    LD A, $15
    OUT ($63), A
    LD A, $4F
    OUT ($64), A
    IN A, ($63)
    CP $15
    RET NZ
    LD A, 2
    OUT ($67), A                ; reinicio
    XOR A
    OUT ($67), A
    LD A, 6
    OUT ($64), A
    LD A, $05                   ; P1
    OUT ($63), A
    LD A, 8
    OUT ($64), A
    LD A, $02                   ; pantalla apagada, 512 KB
    OUT ($63), A
    ; patrones del espejo ($00000-$05FFF) a 0
    XOR A
    OUT ($64), A
    OUT ($63), A
    OUT ($63), A
    OUT ($63), A
    LD BC, $6000
.BORRAR:
    XOR A
    OUT ($60), A
    DEC BC
    LD A, B
    OR C
    JR NZ, .BORRAR
    LD IX, TABLA_V9990
.FRAGMENTO:
    LD A, (IX+0)
    CP $FF
    JR Z, .FIN
    XOR A
    OUT ($64), A                ; R#0: puntero de escritura
    LD A, (IX+1)
    OUT ($63), A
    LD A, (IX+2)
    OUT ($63), A
    LD A, (IX+0)
    OUT ($63), A
    LD A, (IX+3)
    LD (BANCO1_REG), A
    LD L, (IX+4)
    LD H, (IX+5)
    LD E, (IX+6)
    LD D, (IX+7)
    LD C, $60
.BLOQUE:
    LD A, D
    AND A
    JR Z, .RESTO
    LD B, 0
    OTIR
    DEC D
    JR .BLOQUE
.RESTO:
    LD A, E
    AND A
    JR Z, .SIGUIENTE
    LD B, A
    OTIR
.SIGUIENTE:
    LD DE, 8
    ADD IX, DE
    JR .FRAGMENTO
.FIN:
    CALL V9_DESCOMPRIMIR
    XOR A
    LD (BANCO1_REG), A
    RET

; --------------------------------------------------------------
;  V9_DESCOMPRIMIR: la portada del V9990 (tools/lz.py) en la direccion
;  $60000 del modo bitmap (fisicamente, los bytes pares en $30000 y los
;  impares en $70000, zonas libres en el modo P1). Se escribe con el
;  V9990 en modo B1 para que el reparto lo haga el propio V9990. Las
;  copias se leen de la propia VRAM con el puntero de lectura (R#3-5),
;  que es independiente del de escritura (R#0-2).
; --------------------------------------------------------------
PORTADA_VRAM EQU $60000         ; tools/graficos.py
V9_DESCOMPRIMIR:
    LD A, 6
    OUT ($64), A
    LD A, $82                   ; B1, 256 px, 8 bpp
    OUT ($63), A
    CALL .TODO
    LD A, 6
    OUT ($64), A
    LD A, $05                   ; P1 otra vez
    OUT ($63), A
    RET
.TODO:
    LD A, (PORTADA_V9990)
    LD (BANCO1_REG), A
    LD (.BANCO), A
    LD HL, (PORTADA_V9990 + 1)
    XOR A
    OUT ($64), A                ; R#0: puntero de escritura
    LD (.DESTINO), A
    LD (.DESTINO + 1), A
    OUT ($63), A
    OUT ($63), A
    LD A, PORTADA_VRAM >> 16
    LD (.DESTINO + 2), A
    OUT ($63), A
.TOKEN:
    CALL .BYTE
    AND A
    RET Z
    LD B, A
    LD C, A
    JP M, .COPIA
.LITERAL:
    CALL .BYTE
    OUT ($60), A
    DJNZ .LITERAL
    LD A, C                     ; C = t bytes escritos
    JR .AVANZAR
.COPIA:
    SUB 125
    LD B, A                     ; longitud
    CALL .BYTE
    LD E, A
    CALL .BYTE
    LD D, A                     ; distancia
    PUSH HL
    LD HL, (.DESTINO)
    AND A
    SBC HL, DE
    LD A, (.DESTINO + 2)
    SBC A, 0
    LD E, A
    LD A, 3
    OUT ($64), A                ; R#3: puntero de lectura
    LD A, L
    OUT ($63), A
    LD A, H
    OUT ($63), A
    LD A, E
    OUT ($63), A
    POP HL
    LD C, B
.LEER:
    IN A, ($60)
    OUT ($60), A
    DJNZ .LEER
    LD A, C
.AVANZAR:
    ; destino += A
    PUSH HL
    LD HL, (.DESTINO)
    ADD A, L
    LD L, A
    JR NC, .SIN_ACARREO
    INC H
    JR NZ, .SIN_ACARREO
    LD A, (.DESTINO + 2)
    INC A
    LD (.DESTINO + 2), A
.SIN_ACARREO:
    LD (.DESTINO), HL
    POP HL
    JR .TOKEN
; A = siguiente byte de la ROM, cambiando de banco al pasar de $7FFF
.BYTE:
    LD A, (HL)
    INC HL
    BIT 7, H
    RET Z
    LD H, $40
    PUSH AF
    LD A, (V9_DESCOMPRIMIR.BANCO)
    INC A
    LD (V9_DESCOMPRIMIR.BANCO), A
    LD (BANCO1_REG), A
    POP AF
    RET
.DESTINO: DS 3
.BANCO:   DB 0

; --------------------------------------------------------------
    INCLUDE "../../build/tabla_carga.inc"

    DISPLAY "fin del cargador en RAM: ", /A, $
    ASSERT $ <= $E800             ; BUFFER
    ENT
CARGADOR_FIN:

    ASSERT CARGADOR_FIN - CARGADOR_ORIGEN <= BUFFER - CARGADOR_RAM

; --------------------------------------------------------------
;  Relleno del banco 0
; --------------------------------------------------------------
    ; Marca para emuladores (nunca se ejecuta): la deteccion automatica
    ; de openMSX cuenta las instrucciones LD (nn),A a direcciones de
    ; registros de mapper. Las 2 escrituras reales a $6000 empatan entre
    ; Konami y ASCII16 y gana Konami; LD ($77FF),A solo cuenta para
    ; ASCII16. No afecta a cartuchos reales.
MARCA_ASCII16:
    DUP 4
    LD ($77FF), A
    EDUP
    ASSERT $ <= INICIO_CARGA
    DS INICIO_CARGA - $, $FF
    ; build.py anade a continuacion build/carga_util.bin (desde aqui, en
    ; el banco 0, hasta el banco n)
