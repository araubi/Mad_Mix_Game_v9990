"""niveles.py -- lee las matrices iniciales de los 15 niveles de la imagen RAM."""
import os
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TABLA_NIVELES = 0x59A9


def memoria():
    m = bytearray(0x10000)
    b = os.path.join(RAIZ, "build")
    for f, d in (("ram_1000.bin", 0x1000), ("ram_6500.bin", 0x6500), ("ram_8400.bin", 0x8400)):
        x = open(os.path.join(b, f), "rb").read()
        m[d:d + len(x)] = x
    return m


def w(m, a):
    return m[a] | m[a + 1] << 8


def registro(m, n):
    return m[TABLA_NIVELES + 20 * n:TABLA_NIVELES + 20 * n + 20]


def matriz(m, n, vuelta=0):
    """Matriz tal como la deja CARGAR_NIVEL (bit 7 ya limpio)."""
    a = TABLA_NIVELES + 20 * n
    cuerpo, cab, pie, filas = w(m, a), w(m, a + 2), w(m, a + 4), m[a + 6]
    comodin = m[a + 12]
    out = bytearray(m[cab:cab + 96])
    e = 0
    for i in range(filas * 32):
        v = m[cuerpo + i] & 0x7F
        if vuelta:
            if v == 60:
                if (e & 1) != vuelta:
                    v = comodin
                e += 1
        out.append(v)
    out += m[pie:pie + 96]
    return out, filas + 6
