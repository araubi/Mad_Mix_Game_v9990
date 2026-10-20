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

BANCO1_REG  EQU $6000           ; ASCII16: banco de la pagina 1
CARGADOR_RAM EQU $E000
BUFFER      EQU $E800
PILA        EQU $F300

ENTRADA_JUEGO EQU $8400         ; START del motor
TIC_FRAMES    EQU $6500         ; optimizaciones.asm: frames por tic del bucle principal
V9_INICIAR    EQU $6C00         ; v9990.asm: detecta e inicia el V9990 (GFX9000)
JIFFY         EQU $FC9E
ENTRADA_LOGO  EQU $9470         ; ENTRADA_LOGOTOPO

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
    JR C, ERROR_SIN_RAM

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

    ; --- logo de Topo Soft (version de cinta), con BIOS presente ---
    LD IX, TABLA_LOGO
    CALL COPIAR_FRAGMENTOS
    EI
    CALL ENTRADA_LOGO
    DI

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

SLOT_ROM:   DB 0
SLOT_RAM:   DB 0
TIC_DETECTADO: DB 6

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
    INCLUDE "../../build/tabla_carga.inc"

    ENT
CARGADOR_FIN:

    ASSERT CARGADOR_FIN - CARGADOR_ORIGEN <= BUFFER - CARGADOR_RAM

; --------------------------------------------------------------
;  Relleno del banco 0
; --------------------------------------------------------------
    DS $8000 - $, $FF
    ; build.py anade a continuacion build/carga_util.bin (bancos 1..n)
