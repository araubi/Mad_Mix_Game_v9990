; --------------------------------------------------------------
;  V9_PEPSI_ROJA: desde V9_TIC en partida, en lugar de CALL V9_PARPADEO.
;  Con The Pepsi Challenge y la bola de poder, la entrada 9 de la paleta
;  de los sprites (41; el amarillo de la mascota, que no usa nadie mas)
;  pasa al rojo de los dibujos del grafista (la 8), para la mascota
;  hacia arriba, que no tiene dibujo rojo; si no, vuelve al amarillo.
;  Va detras de volumen.asm (o en $0040 sin el), en TABLA_EXT.
; --------------------------------------------------------------
V9_PEPSI_ROJA:
    LD A, (MODO_PEPSI)
    AND A
    JR Z, .PONER                ; A = 0: amarillo
    LD A, (MODO_ESPECIAL)
    AND $07
    DEC A
    LD A, 0
    JR NZ, .PONER
    INC A                       ; 1: rojo
.PONER:
    LD HL, V9_PEPSI_ROJA_ESTADO
    CP (HL)
    JP Z, V9_PARPADEO
    LD (HL), A
    LD HL, V9_PALETA_SPRITES + 9 * 3
    AND A
    JR Z, .COLOR
    LD HL, V9_PALETA_SPRITES + 8 * 3
.COLOR:
    LD A, 32 + 9
    LD C, 1
    DI
    CALL V9_CARGAR_PALETA
    EI
    JP V9_PARPADEO
V9_PEPSI_ROJA_ESTADO: DB 0
FIN_PEPSI_ROJA:
    ASSERT FIN_PEPSI_ROJA <= $0100
