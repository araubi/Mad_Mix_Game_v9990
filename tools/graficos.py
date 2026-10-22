#!/usr/bin/env python3
"""
graficos.py -- Mad Mix Game v9990: convierte los graficos del remake
(carpeta graficos/remake, del grafista) al formato del V9990 en modo P1.

Necesita build/ram_*.bin (lo llama build.py despues de ensamblar el
juego) y Pillow. Genera en build/:

  v9_losetas.bin   losetas de 16x16 del laberinto, mapa de 256 px de
                   ancho a 4 bpp (generador de la capa B, $40000)
  v9_niveles.bin   15 bloques de 4 KB, uno por nivel ($20000 + (n-1)*$1000):
                     +$000  celdas: 4 bytes por loseta de la matriz
                            (v0, t0 bajo, t1 bajo, t0 alto | t1 alto << 4)
                            v0 = valor inicial de la matriz, t0 = loseta
                            del dibujo del grafista, t1 = el suelo que
                            queda debajo cuando se come lo que hay
                     +$E80  paleta de la capa B (16 x 3 bytes, 5 bits)
                     +$F00  loseta de respaldo para cada valor 0-127
                            (2 bytes), para valores que no son ni v0 ni
                            la loseta comodin del nivel
  v9_capa_a.bin    generador de la capa A desde $06000: patrones fijos
                   (transparente, negro), cifras, letras e icono de vida
                   del marcador, el marco (desde $08000) y la portada
                   (desde $10000)
  v9_sprites.bin   patrones de sprite de 16x16 (SPRITES_VRAM)
  v9_datos.inc     paletas fijas y tabla de sprites por actor (RAM)

Uso: python3 tools/graficos.py
"""
import os
import struct
import sys
from collections import Counter

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import niveles  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD = os.path.join(RAIZ, "build")
REMAKE = os.path.join(RAIZ, "graficos", "remake")

MAGENTA = (0xFF, 0x00, 0xF6)
CIAN, CIAN_SOMBRA, ROJO = (76, 221, 254), (40, 111, 178), (203, 49, 7)   # sprites del remake
# Colores casi iguales que el grafista uso por descuido (ANALISIS.md)
ARREGLOS = {(0xFE, 0xFE, 0xFE): (0xFF, 0xFF, 0xFF), (0xED, 0xED, 0x2D): (0xFC, 0xFC, 0x6F),
            (0xFF, 0xFF, 0x00): (0xFC, 0xFC, 0x6F), (0xDF, 0xDF, 0x2F): (0xFC, 0xFC, 0x6F)}
# Colores de fondo que los mapas usan fuera de su paleta: van a la entrada 10
# (la 10 no la usa ningun laberinto). En el nivel 2 la hoja propia trae un
# color 11 distinto del mapa; manda el mapa (el de la hoja 2-10).
EXTRA = {2: (0x16, 0x20, 0x1F), 6: (0x4A, 0x36, 0x2E), 14: (0x4A, 0x36, 0x2E), 9: (0x13, 0x00, 0x1F)}

NIVELES = range(1, 16)
BLOQUE_NIVEL = 0x1000
MAX_LOSETAS = 1920              # $40000-$7BFFF: 120 filas de 16 losetas


def ruta(nombre):
    return os.path.join(REMAKE, nombre)


def rgb(im):
    return im.convert("RGB")


def c5(c):
    """Color de 8 bits por componente -> 3 bytes de 5 bits (R, G, B) del V9990."""
    return bytes(v * 31 // 255 for v in c)


def cercano(c, paleta, desde=1):
    return min(range(desde, len(paleta)),
               key=lambda i: sum((a - b) ** 2 for a, b in zip(c, paleta[i])))


def cuantizar(im, paleta, transparente=None):
    """Imagen -> indices de la paleta (1-15; 0 para el color transparente)."""
    px = im.load()
    w, h = im.size
    out = bytearray(w * h)
    cache = {}
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c == transparente:
                continue
            c = ARREGLOS.get(c, c)
            if c not in cache:
                cache[c] = paleta.index(c, 1) if c in paleta[1:] else cercano(c, paleta)
            out[y * w + x] = cache[c]
    return out, w, h


def empaquetar(ind):
    """Lista de indices (pares) -> bytes a 4 bpp, el pixel izquierdo en el nibble alto."""
    return bytes((ind[i] << 4) | ind[i + 1] for i in range(0, len(ind), 2))


# ----------------------------------------------------------------------
#  Laberinto
# ----------------------------------------------------------------------
def paleta_nivel(n):
    hoja = rgb(Image.open(ruta(f"paletafase{n}.png")))
    p = [hoja.getpixel((i * 8 + 4, 4)) for i in range(16)]
    if n in EXTRA:
        p[10] = EXTRA[n]
    if n == 2:
        p[10], p[11] = p[11], EXTRA[2]
    return p


def losetas_mapa(n, paleta, filas):
    im = rgb(Image.open(ruta(f"madmixmapfase{n}.png")))
    q, w, _ = cuantizar(im, paleta)
    oy = 16 if n == 1 else 0     # el mapa del nivel 1 trae 16 px de mas arriba
    celdas = [[bytes(q[(oy + r * 16 + j) * w + c * 16 + i] for j in range(16) for i in range(16))
               for c in range(32)] for r in range(filas)]
    return celdas


def alinear(celdas, m, filas):
    """Los mapas del grafista estan girados en horizontal (el laberinto da la
    vuelta): busca el giro de columnas con el que cada valor de la matriz
    tiene casi siempre la misma loseta. Devuelve las losetas en el orden de
    la matriz y el giro."""
    mejor = None
    for giro in range(32):
        por_valor = {}
        for r in range(filas):
            for c in range(32):
                por_valor.setdefault(m[r * 32 + c], Counter())[celdas[r][(c + giro) % 32]] += 1
        nota = sum(c.most_common(1)[0][1] for c in por_valor.values())
        if mejor is None or nota > mejor[0]:
            mejor = (nota, giro)
    giro = mejor[1]
    return [celdas[r][(c + giro) % 32] for r in range(filas) for c in range(32)], giro, mejor[0] / (filas * 32)


def loseta_original(mem, v):
    """Loseta original de 1 bpp a 4 bpp: tinta 4, fondo 15 (solo de respaldo)."""
    v &= 0x7F
    if v >= 91:
        v = 0
    g = mem[0xB940 + v * 32:0xB940 + v * 32 + 32]
    return bytes(4 if (g[f * 2 + (x >> 3)] >> (7 - (x & 7))) & 1 else 15
                 for f in range(16) for x in range(16))


def distancia(a, b):
    return sum(1 for x, y in zip(a, b) if x != y)


def laberinto(mem):
    ids = {}
    lista = []

    def id_de(t):
        if t not in ids:
            ids[t] = len(lista)
            lista.append(t)
        return ids[t]

    datos = {}
    for n in NIVELES:
        pal = paleta_nivel(n)
        m, filas = niveles.matriz(mem, n)
        comodin = niveles.registro(mem, n)[12]
        t, giro, nota = alinear(losetas_mapa(n, pal, filas), m, filas)
        print(f"  nivel {n:2}: giro de {giro:2} columnas, coincidencia {nota:.0%}")
        datos[n] = (pal, m, filas, comodin, t)

    # Respaldo de cada valor: la loseta mas frecuente con ese valor inicial,
    # primero en el propio nivel, luego en los niveles de la misma paleta y
    # por ultimo en cualquiera.
    grupos = {}
    for n in NIVELES:
        grupos.setdefault(tuple(datos[n][0]), []).append(n)
    frecuentes = {}
    for n in NIVELES:
        _, m, filas, _, t = datos[n]
        f = {}
        for i in range(filas * 32):
            f.setdefault(m[i], Counter())[t[i]] += 1
        frecuentes[n] = {v: c.most_common(1)[0][0] for v, c in f.items()}

    niveles_bin = bytearray()
    for n in NIVELES:
        pal, m, filas, comodin, t = datos[n]
        # suelo de cada celda: el mas parecido de los que aparecen sobre todo
        # con el valor comodin (alguna celda comodin del mapa trae una bola
        # dibujada, y alguna otra celda trae el suelo liso)
        en_comodin = Counter(t[i] for i in range(filas * 32) if m[i] == comodin)
        en_otras = Counter(t[i] for i in range(filas * 32) if m[i] != comodin)
        suelos = sorted(k for k, c in en_comodin.items() if c > en_otras[k]) \
            or [frecuentes[n].get(comodin)]
        # celdas con bola (u otro objeto) que el mapa del grafista trae
        # vacias (en el nivel 1, junto a la salida del comecocos): se
        # dibujan con la loseta del mismo valor sobre el suelo mas parecido
        con_valor = {}
        for i in range(filas * 32):
            if t[i] not in suelos:
                con_valor.setdefault(m[i], set()).add(t[i])
        arregladas = 0
        t = list(t)
        for i in range(filas * 32):
            if m[i] != comodin and t[i] in suelos and frecuentes[n][m[i]] not in suelos \
                    and m[i] in con_valor:
                t[i] = min(sorted(con_valor[m[i]]), key=lambda x: distancia(x, t[i]))
                arregladas += 1
        if arregladas:
            print(f"  nivel {n:2}: {arregladas} celdas sin su objeto en el mapa")
        bloque = bytearray(BLOQUE_NIVEL)
        for i in range(filas * 32):
            t0 = t[i]
            if m[i] == comodin or not suelos[0]:
                t1 = t0
            else:
                t1 = min(suelos, key=lambda s: distancia(s, t0))
            a, b = id_de(t0), id_de(t1)
            bloque[i * 4:i * 4 + 4] = bytes((m[i], a & 0xFF, b & 0xFF, (a >> 8) | ((b >> 8) << 4)))
        pal_bin = b"".join(c5(c) for c in pal)
        bloque[0xE80:0xE80 + 48] = pal_bin
        orden = [n] + [k for k in grupos[tuple(pal)] if k != n] + [k for k in NIVELES if k != n]
        for v in range(128):
            # La chispa de la linea electrica de la puerta de los fantasmas
            # alterna los valores $38 y $39, y casi ningun mapa trae los dos:
            # el que falta es la del nivel dada la vuelta (parpadea igual).
            pareja = {0x38: 0x39, 0x39: 0x38}.get(v)
            if v not in frecuentes[n] and pareja in frecuentes[n]:
                t0 = frecuentes[n][pareja]
                r = bytes(t0[j * 16 + 15 - x] for j in range(16) for x in range(16))
            else:
                for k in orden:
                    if v in frecuentes[k]:
                        r = frecuentes[k][v]
                        break
                else:
                    r = loseta_original(mem, v)
            struct.pack_into("<H", bloque, 0xF00 + v * 2, id_de(r))
        niveles_bin += bloque

    if len(lista) > MAX_LOSETAS:
        sys.exit(f"ERROR: {len(lista)} losetas, caben {MAX_LOSETAS}")
    filas_bmp = (len(lista) + 15) // 16 * 16
    bmp = bytearray(filas_bmp * 128)
    for k, t in enumerate(lista):
        x0, y0 = (k % 16) * 16, (k // 16) * 16
        for j in range(16):
            fila = empaquetar(t[j * 16:j * 16 + 16])
            o = (y0 + j) * 128 + x0 // 2
            bmp[o:o + 8] = fila
    return bytes(bmp), bytes(niveles_bin), len(lista)


# ----------------------------------------------------------------------
#  Capa A: marcador, marco y portada
# ----------------------------------------------------------------------
# Ventana del laberinto en la pantalla del TMS (la del V9990 va 8 lineas
# mas abajo).
VENTANA = (32, 16, 224, 160)
VIDAS = (72, 176, 184, 192)     # zona de los iconos de vida
PUNTOS = (176, 176, 224, 192)   # zona del marcador


def paleta_marco():
    m = rgb(Image.open(ruta("madmix.png")))
    sp = rgb(Image.open(ruta("or fase 1.png")))
    c = Counter()
    for y in range(196):
        for x in range(256):
            if VENTANA[0] <= x < VENTANA[2] and VENTANA[1] <= y < VENTANA[3]:
                continue
            c[ARREGLOS.get(m.getpixel((x, y)), m.getpixel((x, y)))] += 1
    for y in range(192, 208):
        for x in range(0, 368):
            p = sp.getpixel((x, y))
            if p != MAGENTA:
                c[ARREGLOS.get(p, p)] += 1
    colores = [k for k, _ in c.most_common()]
    negro = (0, 0, 0)
    colores.remove(negro)
    pal = [MAGENTA, negro] + colores
    if len(pal) > 16:
        sys.exit(f"ERROR: el marco usa {len(pal) - 1} colores")
    pal += [negro] * (16 - len(pal))
    return pal


def capa_a(pal):
    """Generador de la capa A desde la linea 192 ($06000) hasta la 727."""
    lineas = 728 - 192
    bmp = bytearray(lineas * 128)

    def poner(x, y, ind, w):
        """ind: indices de w px de ancho en (x, y) del mapa de la capa A."""
        h = len(ind) // w
        for j in range(h):
            o = (y + j - 192) * 128 + x // 2
            bmp[o:o + w // 2] = empaquetar(ind[j * w:(j + 1) * w])

    # fila 24: patron 768 transparente, 769 negro
    poner(8, 192, bytes([1]) * 64, 8)
    # filas 25-26: cifras verdes (8x16) del remake, la d en los patrones 800+d / 832+d
    sp = rgb(Image.open(ruta("or fase 1.png")))
    for d in range(10):
        q, _, _ = cuantizar(sp.crop((8 + 16 * d, 192, 16 + 16 * d, 208)), pal, MAGENTA)
        poner(d * 8, 200, bytes(i or 1 for i in q), 8)
    # filas 27-28: letras blancas (8x8) en la mitad de abajo, A-Z en 864+i / 896+i
    for i in range(26):
        q, _, _ = cuantizar(sp.crop((160 + 8 * i, 192, 168 + 8 * i, 200)), pal, MAGENTA)
        poner(i * 8, 216, bytes([1]) * 32 + bytes(v or 1 for v in q[:32]), 8)
        poner(i * 8, 224, bytes(v or 1 for v in q[32:]) + bytes([1]) * 32, 8)
    # filas 29-30: icono de vida (16x16), patrones 928-929 / 960-961
    m = rgb(Image.open(ruta("madmix.png")))
    q, _, _ = cuantizar(m.crop((VIDAS[0], VIDAS[1], VIDAS[0] + 16, VIDAS[1] + 16)), pal)
    poner(0, 232, q, 16)

    # marco: 27 filas de patrones desde la 32 (linea 256); la linea y del V9990
    # es la y-8 de la maqueta
    q, w, _ = cuantizar(m, pal)
    marco = bytearray(216 * 256)
    for y in range(8, 8 + 188):
        my = y - 8
        for x in range(256):
            v = q[my * w + x]
            if VENTANA[0] <= x < VENTANA[2] and VENTANA[1] <= my < VENTANA[3]:
                continue        # ventana: transparente, se ve la capa B
            if (VIDAS[0] <= x < VIDAS[2] or PUNTOS[0] <= x < PUNTOS[2]) and VIDAS[1] <= my < VIDAS[3]:
                v = 1           # lo dibuja el marcador
            marco[y * 256 + x] = v or 1
    for y in list(range(8)) + list(range(196, 216)):
        for x in range(256):
            marco[y * 256 + x] = 1
    poner(0, 256, marco, 256)
    return bytes(bmp)


def portada():
    """portada.SC5 (BSAVE de SCREEN 5) -> mapa de 212 lineas y paleta de 16 colores."""
    d = open(ruta("portada.SC5"), "rb").read()
    if d[0] != 0xFE:
        sys.exit("ERROR: portada.SC5 no es un BSAVE")
    datos = d[7:]
    bmp = datos[:212 * 128]
    p = datos[0x7680:0x7680 + 32]
    pal = bytearray()
    for i in range(16):
        r, b, g = p[i * 2] >> 4 & 7, p[i * 2] & 7, p[i * 2 + 1] & 7
        pal += bytes((r * 31 // 7, g * 31 // 7, b * 31 // 7))
    return bmp, bytes(pal)


# ----------------------------------------------------------------------
#  Sprites
# ----------------------------------------------------------------------
Y0, Y48 = 0, 48


def c16(x, y):
    return (x, y, 16, 16)


# Sprite original (PTR_TABLA_SPRITES, 0-63) -> rectangulo de la hoja del
# remake, y el de la version espejo cuando el grafista la dibujo aparte
# (si no, se refleja).
SPRITES = {
    0: (c16(48, Y48), c16(0, Y48)), 1: (c16(64, Y48), c16(16, Y48)), 2: (c16(80, Y48), c16(32, Y48)),
    3: (c16(128, Y48), None), 4: (c16(112, Y48), None), 5: (c16(96, Y48), None),
    6: (c16(144, Y48), None),
    7: (c16(320, Y0), c16(368, Y0)), 8: (c16(336, Y0), c16(384, Y0)), 9: (c16(352, Y0), c16(400, Y0)),
    10: (c16(288, Y0), None), 11: (c16(256, Y0), None), 57: (c16(272, Y0), None),
    12: ((294, 110, 19, 18), None),
    13: ((384, 112, 20, 16), None), 14: ((384, 112, 20, 16), None), 15: ((384, 112, 20, 16), None),
    16: ((6, 106, 22, 22), (196, 106, 22, 22)), 17: ((38, 106, 22, 22), (228, 106, 22, 22)),
    18: ((70, 106, 22, 22), (260, 106, 22, 22)),
    19: ((96, 106, 16, 22), None), 20: ((112, 106, 16, 22), None), 24: ((128, 106, 16, 22), None),
    21: ((144, 106, 16, 22), None), 22: ((160, 106, 16, 22), None), 25: ((176, 106, 16, 22), None),
    23: ((5, 213, 22, 22), None),
    26: (c16(336, Y48), None),
    # fantasmas: el dibujo de x=32/48 (y 128/144) mira a la derecha
    27: (c16(32, Y0), c16(64, Y0)), 28: (c16(48, Y0), c16(80, Y0)),
    29: (c16(0, Y0), None), 30: (c16(16, Y0), None),
    # el 31 y el 32 reflejados son los fantasmas vulnerables hacia arriba
    # (blancos; el juego usa los azules, ver V9_FANTASMAS_BLANCOS)
    31: (c16(96, Y0), c16(224, Y0)), 32: (c16(112, Y0), c16(240, Y0)),
    33: (c16(128, Y0), c16(160, Y0)), 34: (c16(144, Y0), c16(176, Y0)),
    35: (c16(192, Y0), None), 36: (c16(208, Y0), None),
    37: (c16(480, Y0), None), 38: (c16(496, Y0), None), 39: (c16(448, Y0), c16(464, Y0)),
    40: (c16(224, Y48), None), 41: (c16(240, Y48), None), 42: (c16(256, Y48), None),
    43: (c16(272, Y48), None), 44: (c16(288, Y48), None),
    45: (c16(464, 96), c16(416, 96)), 46: (c16(480, 96), c16(432, 96)), 47: (c16(496, 96), c16(448, 96)),
    48: (c16(464, Y48), None), 49: (c16(480, Y48), None), 50: (c16(496, Y48), None),
    51: (c16(416, Y48), None), 52: (c16(432, Y48), None), 53: (c16(448, Y48), None),
    54: (c16(464, Y48), None),
    55: (c16(304, Y48), None), 56: (c16(320, Y48), None),
    58: (c16(160, Y48), None), 59: (c16(176, Y48), None), 60: (c16(192, Y48), None), 61: (c16(208, Y48), None),
    62: (c16(416, Y0), None),
    # 64: no existe en el original; con el V9990 es el comecocos rojo
    # hacia arriba (el juego usa el 6, amarillo, tambien con la bola de
    # poder; lo cambia V9_META_ELEGIR)
    64: (c16(304, Y0), None),
}


def caja(puntos):
    xs = [p[0] for p in puntos]
    ys = [p[1] for p in puntos]
    return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2


def original(mem, i, espejo):
    """Pixeles visibles del sprite original i (24x24), donde los pone el
    TMS. Reflejado, el motor lo dibuja ademas desplazado a la izquierda
    tantos pixeles como columnas libres tenga a la derecha (bits 0-2 del
    indicador, $843F en MOTOR_ACTORES)."""
    base = mem[0x91C3 + i * 4] | mem[0x91C4 + i * 4] << 8
    hueco = mem[0x91C5 + i * 4] & 7
    d = mem[base:base + 144]
    pts = []
    for r in range(24):
        for c in range(24):
            b = r * 6 + c // 8
            mascara = (d[b] >> (7 - c % 8)) & 1
            tinta = (d[b + 3] >> (7 - c % 8)) & 1
            if tinta or not mascara:
                pts.append((23 - hueco - c if espejo else c, r))
    return pts


def sprites(mem):
    sp = rgb(Image.open(ruta("or fase 1.png")))
    c = Counter()
    for a, b in SPRITES.values():
        for r in (a, b):
            if r:
                x, y, w, h = r
                c.update(p for p in sp.crop((x, y, x + w, y + h)).getdata() if p != MAGENTA)
    colores = sorted({ARREGLOS.get(k, k) for k in c})
    pal = [MAGENTA] + colores
    if len(pal) > 16:
        sys.exit(f"ERROR: los sprites usan {len(pal) - 1} colores")
    pal += [(0, 0, 0)] * (16 - len(pal))
    # Entradas fijas para los colores nuevos (V9_META_ELEGIR elige la paleta
    # de cada sprite: 32-47 o la del TMS, 0-15):
    #  9  amarillo de la mascota de Pepsi (en la del TMS, rojo claro: la
    #     mascota roja con la bola de poder); el rosa que estaba va al 15
    #  12 rojo oscuro (sombra del fantasma rojo)
    #  13, 6, 14: cuerpo, sombra y ojos del fantasma naranja; en la del
    #     TMS, el rosa (magenta, rojo oscuro, gris)
    esperado = {1: (0, 0, 0), 3: CIAN_SOMBRA, 5: CIAN, 6: (93, 93, 93), 8: ROJO,
                10: (252, 252, 111), 11: (255, 255, 255)}
    for k, v in esperado.items():
        if pal[k] != v:
            sys.exit(f"ERROR: color {k} de los sprites {pal[k]}, se esperaba {v}")
    if len(colores) > 11:
        sys.exit("ERROR: los sprites ya usan las entradas 12-15")
    pal_q = list(pal)           # la de cuantizar (sin repetidos)
    pal[15] = pal[9]
    pal[9] = pal[10]
    pal[12] = (120, 24, 8)
    pal[13] = (255, 160, 40)
    pal[14] = (255, 255, 255)

    patrones = []
    vistos = {}

    def patron(ind):
        if ind not in vistos:
            vistos[ind] = len(patrones)
            patrones.append(ind)
        return vistos[ind]

    meta = {}
    for i in range(65):
        for espejo in (0, 1):
            if espejo and i in (29, 30):
                continue                # el juego no los usa reflejados
            if i not in SPRITES:
                meta[(i, espejo)] = []
                continue
            a, b = SPRITES[i]
            r = (b if espejo else a) or a
            reflejar = espejo and not b
            x, y, w, h = r
            q, _, _ = cuantizar(sp.crop((x, y, x + w, y + h)), pal_q, MAGENTA)
            q = bytes(15 if v == 9 else v for v in q)     # el rosa va al 15
            if reflejar:
                q = bytes(q[j * w + w - 1 - k] for j in range(h) for k in range(w))
            pts = [(k, j) for j in range(h) for k in range(w) if q[j * w + k]]
            if not pts:
                meta[(i, espejo)] = []
                continue
            ox, oy = caja(original(mem, 6 if i == 64 else i, espejo))
            rx, ry = caja(pts)
            dx, dy = round(ox - rx), round(oy - ry)
            partes = []
            for py in range(0, h, 16):
                for px in range(0, w, 16):
                    ind = bytes(q[(py + j) * w + px + k] if py + j < h and px + k < w else 0
                                for j in range(16) for k in range(16))
                    if any(ind):
                        partes.append((dx + px, dy + py, patron(ind)))
            meta[(i, espejo)] = partes
    for i in (29, 30):
        meta[(i, 1)] = meta[(i, 0)]
    # Fantasmas de colores, como en Pac-Man (V9_META_ELEGIR): el rojo y el
    # naranja (rosa con la paleta del TMS) con sus propios patrones; el
    # cian es el del grafista. Los 31 y 32 reflejados (blancos) no cambian.
    meta_color = {}
    for nombre, cambio in (("ROJO", {5: 8, 3: 12}), ("NARANJA", {5: 13, 3: 6, 11: 14})):
        for i in range(27, 33):
            for e in (0, 1):
                partes = meta[(i, e)]
                if not (e and i in (31, 32)):
                    partes = [(dx, dy, patron(bytes(cambio.get(v, v) for v in patrones[p])))
                              for dx, dy, p in partes]
                meta_color[(nombre, i, e)] = partes
    meta_pepsi = sprites_pepsi(mem, sp, pal, patron)
    if len(patrones) > 256:
        sys.exit(f"ERROR: {len(patrones)} patrones de sprite, caben 256")
    bmp = bytearray(256 * 128)
    for k, ind in enumerate(patrones):
        x0, y0 = (k % 16) * 16, (k // 16) * 16
        for j in range(16):
            o = (y0 + j) * 128 + x0 // 2
            bmp[o:o + 8] = empaquetar(ind[j * 16:j * 16 + 16])
    filas = (len(patrones) + 15) // 16 * 16
    return bytes(bmp[:filas * 128]), pal, meta, meta_pepsi, meta_color, len(patrones)


# ----------------------------------------------------------------------
#  The Pepsi Challenge (opcion 3 del menu): la mascota en lugar del
#  comecocos. Sprites de la cinta inglesa (Topo / US Gold, 1988).
# ----------------------------------------------------------------------
# The Pepsi Challenge tiene 66 sprites: el 64 y el 65 son la mascota
# andando hacia arriba (Mad Mix usa el 6 quieto). Aqui no caben: el 64 va
# en el 63 (el nulo, sin usar) y el 65 es el 64 reflejado con 5 columnas
# libres a la derecha (identicos salvo un pixel).
PEPSI_IDS = list(range(12)) + list(range(57, 62)) + [63]
PEPSI_FLAGS = {0: 2, 1: 2, 2: 2, 7: 2, 8: 2, 9: 2, 63: 5}   # el resto, como en Mad Mix
SPR_BASE = 0x953B                                      # sprite 0 (PTR_TABLA_SPRITES)
PTR_SPRITES = 0x91C3                                   # PTR_TABLA_SPRITES
PEPSI_SPR63 = 0x7F60                                   # pepsi.asm: el 63 de Pepsi (solo TMS)
SUBTABLAS = 0x2C50                                     # SUBTABLA_DIRECCION_A
# SUBTABLA_DIRECCION_A+16 .. SUBTABLA_DIRECCION_B+19 (arriba de A; abajo
# y arriba de B): Mad Mix y The Pepsi Challenge (sus $40/$41 son aqui
# $3F/$BF)
TABLAS_MAD_MIX = bytes([6, 6, 6, 6] + [0xFE] * 4 + [7, 8, 9, 8, 0x87, 0x88, 0x89, 0x88]
                       + [0x0A, 0x39, 0x0B, 0x39, 6, 6, 6, 6])
TABLAS_PEPSI = bytes([0x3F, 6, 0xBF, 6] + [0xFE] * 4 + [7, 8, 9, 8, 0x87, 0x88, 0x89, 0x88]
                     + [0x0A, 0x0B, 0x39, 0x0B, 0x3F, 6, 0xBF, 6])


def datos_pepsi():
    d = open(os.path.join(RAIZ, "src", "juego", "data", "pepsi", "sprites_pepsi.bin"), "rb").read()
    return {i: d[k * 144:(k + 1) * 144] for k, i in enumerate(PEPSI_IDS)}


def sprites_pepsi(mem, sp, pal, patron):
    """Partes (dx, dy, patron) de la mascota de Pepsi para el V9990: los
    pixeles que la mascara borra en el amarillo del comecocos del remake y
    los de tinta (las lineas, oscuras en el TMS) en negro, en la misma cuadricula de 24x24 que el
    original. Al reflejar se respeta el hueco de la derecha (el byte de
    indicador de PTR_TABLA_SPRITES)."""
    x, y, w, h = SPRITES[0][0]
    c = Counter(p for p in sp.crop((x, y, x + w, y + h)).getdata() if p != MAGENTA)
    amarillo = 9                # ver sprites(): rojo claro en la paleta del TMS
    negro = cercano((0, 0, 0), pal)
    meta = {}
    for i, d in datos_pepsi().items():
        hueco = PEPSI_FLAGS.get(i, mem[0x91C3 + i * 4 + 2]) & 7
        ancho = max(c for r in range(24) for c in range(24)
                    if (d[r * 6 + 3 + c // 8] >> (7 - c % 8)) & 1 or not (d[r * 6 + c // 8] >> (7 - c % 8)) & 1)
        borde = max(23 - hueco, ancho)
        # solo las vistas de lado tienen version reflejada propia (no
        # caben mas patrones); las demas usan la misma
        for espejo in ((0, 1) if i in PEPSI_FLAGS else (0,)):
            q = [0] * (32 * 32)
            for r in range(24):
                for col in range(24):
                    b = r * 6 + col // 8
                    mascara = (d[b] >> (7 - col % 8)) & 1
                    tinta = (d[b + 3] >> (7 - col % 8)) & 1
                    if tinta or not mascara:
                        cx = borde - col if espejo else col
                        if True:
                            q[r * 32 + cx] = negro if tinta else amarillo
            partes = []
            for py in (0, 16):
                for px in (0, 16):
                    ind = bytes(q[(py + j) * 32 + px + k] for j in range(16) for k in range(16))
                    if any(ind):
                        partes.append((px, py, patron(ind)))
            meta[(i, espejo)] = partes
        if i not in PEPSI_FLAGS:
            meta[(i, 1)] = meta[(i, 0)]
    return meta


def delta_pepsi(mem):
    """XOR entre los sprites de Mad Mix y los de Pepsi (0-61), en tramos
    (saltar, n, n bytes); fin = (0, 0). Aplicarlo dos veces deja Mad Mix."""
    pep = datos_pepsi()
    a = bytes(mem[SPR_BASE:SPR_BASE + 62 * 144])
    b = bytearray(a)
    for i, d in pep.items():
        if i < 62:
            b[i * 144:(i + 1) * 144] = d
    return tramos(a, b)


def delta_pepsi_tablas(mem):
    """Los otros dos XOR, en el mismo formato: las subtablas de direccion
    (desde SUBTABLA_DIRECCION_A+16) y los indicadores de
    PTR_TABLA_SPRITES (desde el del sprite 0) con el puntero del 63."""
    a = bytes(mem[SUBTABLAS + 16:SUBTABLAS + 40])
    if a != TABLAS_MAD_MIX:
        sys.exit("ERROR: las subtablas de direccion no son las esperadas")
    sub = tramos(a, TABLAS_PEPSI)
    a = bytes(mem[PTR_SPRITES + 2:PTR_SPRITES + 255])
    b = bytearray(a)
    for i, f in PEPSI_FLAGS.items():
        b[i * 4] = (b[i * 4] & ~7) | f
    b[63 * 4 - 2] = PEPSI_SPR63 & 0xFF
    b[63 * 4 - 1] = PEPSI_SPR63 >> 8
    return sub, tramos(a, b)


def tramos(a, b):
    x = bytes(p ^ q for p, q in zip(a, b))
    out = bytearray()
    k = 0
    while k < len(x):
        s = 0
        while k < len(x) and x[k] == 0 and s < 255:
            s += 1
            k += 1
        n = 0
        while k + n < len(x) and x[k + n] != 0 and n < 255:
            n += 1
        if k >= len(x):
            break
        if n == 0 and s == 0:
            continue
        out += bytes((s, n)) + x[k:k + n]
        k += n
    out += b"\0\0"
    return bytes(out)


# ----------------------------------------------------------------------
def tabla_tms_a(pal):
    """Color del TMS9918 -> entrada de la paleta del marco (capa A en
    partida), para los textos sobre la ventana (FASE, READY?...). Los
    colores sin uno parecido en el marco ocupan las entradas libres
    (la paleta se amplia aqui mismo)."""
    tms = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237), (125, 118, 252),
           (212, 82, 77), (66, 235, 245), (252, 85, 84), (255, 121, 120), (212, 193, 84),
           (230, 206, 128), (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]
    libres = [i for i in range(2, 16) if pal[i] == (0, 0, 0)]

    def dist(c):
        i = cercano(c, pal)
        return sum((a - b) ** 2 for a, b in zip(c, pal[i]))
    # primero los de READY? (13 y 14), luego los mas alejados
    orden = [13, 14] + sorted((t for t in range(2, 16) if t not in (13, 14)),
                              key=lambda t: -dist(tms[t]))
    for t in orden:
        if libres and dist(tms[t]) > 3 * 24 ** 2:
            pal[libres.pop(0)] = tms[t]
    return [0] + [cercano(c, pal) for c in tms[1:]]


def main():
    mem = niveles.memoria()
    losetas, niveles_bin, n_losetas = laberinto(mem)
    pal_marco = paleta_marco()
    capa = capa_a(pal_marco)
    bmp_portada, pal_portada = portada()
    spr, pal_spr, meta, meta_pepsi, meta_color, n_patrones = sprites(mem)

    # capa A: $06000-$0EBFF (glifos y marco) y la portada en $10000
    capa = bytearray(capa)
    o = (512 - 192) * 128
    capa[o:o + len(bmp_portada)] = bmp_portada

    open(os.path.join(BUILD, "v9_losetas.bin"), "wb").write(losetas)
    open(os.path.join(BUILD, "v9_niveles.bin"), "wb").write(niveles_bin)
    open(os.path.join(BUILD, "v9_capa_a.bin"), "wb").write(bytes(capa).rstrip(b"\0"))
    open(os.path.join(BUILD, "v9_sprites.bin"), "wb").write(spr)

    L = ["; generado por tools/graficos.py -- no editar", ""]

    def db(nombre, datos):
        L.append(f"{nombre}:")
        for k in range(0, len(datos), 16):
            L.append("    DB " + ", ".join(str(b) for b in datos[k:k + 16]))

    tms_a = tabla_tms_a(pal_marco)
    db("V9_PALETA_MARCO", b"".join(c5(c) for c in pal_marco))
    db("V9_TMS_A_MARCO", bytes(tms_a))
    db("V9_PALETA_PORTADA", pal_portada)
    db("V9_PALETA_SPRITES", b"".join(c5(c) for c in pal_spr))
    # tabla de sprites: 128 punteros (sprite*2 + espejo) a listas de
    # partes: n, y n veces (dx, dy, patron); el 64 (rojo hacia arriba) va
    # en v9_pepsi.inc, que no cabe aqui
    L.append("V9_META:")
    for i in range(64):
        for e in (0, 1):
            L.append(f"    DW V9_META_{i}_{e}")
    usados = {}
    for i in range(64):
        for e in (0, 1):
            partes = meta[(i, e)]
            clave = tuple(partes)
            if clave in usados:
                L.append(f"V9_META_{i}_{e} EQU {usados[clave]}")
                continue
            usados[clave] = f"V9_META_{i}_{e}"
            L.append(f"V9_META_{i}_{e}:")
            L.append(f"    DB {len(partes)}" + "".join(f", {dx & 0xFF}, {dy & 0xFF}, {p}" for dx, dy, p in partes))
    open(os.path.join(BUILD, "v9_datos.inc"), "w").write("\n".join(L) + "\n")

    # Pepsi: XOR de los sprites para el TMS y partes para el V9990
    open(os.path.join(BUILD, "pepsi_delta.bin"), "wb").write(delta_pepsi(mem))
    sub, ind = delta_pepsi_tablas(mem)
    open(os.path.join(BUILD, "pepsi_subtablas.bin"), "wb").write(sub)
    open(os.path.join(BUILD, "pepsi_indicadores.bin"), "wb").write(ind)
    L = ["; generado por tools/graficos.py -- no editar", "",
         "; punteros (sprite*2 + espejo) de los sprites 0-11, 57-61 y 63"]
    L.append("V9_META_PEPSI:")
    for i in PEPSI_IDS:
        for e in (0, 1):
            L.append(f"    DW V9_META_PEPSI_{i}_{e}")
    for i in PEPSI_IDS:
        for e in (0, 1):
            partes = meta_pepsi[(i, e)]
            L.append(f"V9_META_PEPSI_{i}_{e}:")
            L.append(f"    DB {len(partes)}" + "".join(f", {dx & 0xFF}, {dy & 0xFF}, {p}" for dx, dy, p in partes))
    for nombre in ("ROJO", "NARANJA"):
        L.append(f"; fantasma {nombre.lower()}: punteros de los sprites 27-32 (sprite*2 + espejo)")
        L.append(f"V9_META_F_{nombre}:")
        for i in range(27, 33):
            for e in (0, 1):
                L.append(f"    DW V9_META_F_{nombre}_{i}_{e}")
        for i in range(27, 33):
            for e in (0, 1):
                partes = meta_color[(nombre, i, e)]
                L.append(f"V9_META_F_{nombre}_{i}_{e}:")
                L.append(f"    DB {len(partes)}" + "".join(f", {dx & 0xFF}, {dy & 0xFF}, {p}" for dx, dy, p in partes))
    partes = meta[(64, 0)]
    L.append("V9_META_ROJO_ARRIBA:")
    L.append(f"    DB {len(partes)}" + "".join(f", {dx & 0xFF}, {dy & 0xFF}, {p}" for dx, dy, p in partes))
    open(os.path.join(BUILD, "v9_pepsi.inc"), "w").write("\n".join(L) + "\n")
    print(f"graficos: {n_losetas} losetas, {n_patrones} patrones de sprite,"
          f" capa A {len(capa)} bytes, niveles {len(niveles_bin)} bytes")


if __name__ == "__main__":
    main()
