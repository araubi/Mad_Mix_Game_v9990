#!/usr/bin/env python3
"""datos.py -- fase 0 del MSX2 (prueba de velocidad del V9938): saca de la
imagen RAM del juego las 91 losetas originales (1 bpp, 16x16) y los
actores (24x24, mascara + tinta) a 4 bpp de SCREEN 5, y la matriz de un
nivel. Necesita build/ram_*.bin (python3 tools/build.py)."""
import os
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "tools"))
import niveles  # noqa: E402

SALIDA = os.path.join(RAIZ, "build", "msx2")
TINTA, FONDO = 1, 2


def nibbles(px):
    return bytes((px[i] << 4) | px[i + 1] for i in range(0, len(px), 2))


def main(nivel=1):
    os.makedirs(SALIDA, exist_ok=True)
    m = niveles.memoria()
    # losetas: mapa de 256 px de ancho, 16 por fila
    filas = (91 + 15) // 16
    bmp = [[0] * 256 for _ in range(filas * 16)]
    for v in range(91):
        g = m[0xB940 + v * 32:0xB940 + v * 32 + 32]
        for f in range(16):
            for x in range(16):
                b = (g[f * 2 + (x >> 3)] >> (7 - (x & 7))) & 1
                bmp[(v // 16) * 16 + f][(v % 16) * 16 + x] = TINTA if b else FONDO
    open(os.path.join(SALIDA, "losetas.bin"), "wb").write(b"".join(nibbles(r) for r in bmp))
    # actores: 10 por fila de 24x24 (0 transparente, fondo donde la mascara
    # abre hueco, tinta)
    ids = [0, 1, 27, 28, 29, 30, 16, 17, 45, 46, 12, 13]
    act = [[0] * 256 for _ in range(48)]
    for k, i in enumerate(ids):
        base = m[0x91C3 + i * 4] | m[0x91C4 + i * 4] << 8
        d = m[base:base + 144]
        for r in range(24):
            for c in range(24):
                b = r * 6 + c // 8
                mascara = (d[b] >> (7 - c % 8)) & 1
                tinta = (d[b + 3] >> (7 - c % 8)) & 1
                v = TINTA if tinta else FONDO if not mascara else 0
                act[(k // 10) * 24 + r][(k % 10) * 24 + c] = v
    open(os.path.join(SALIDA, "actores.bin"), "wb").write(b"".join(nibbles(r) for r in act))
    mm, f = niveles.matriz(m, nivel)
    open(os.path.join(SALIDA, "matriz.bin"), "wb").write(bytes(mm))
    open(os.path.join(SALIDA, "matriz.inc"), "w").write(f"FILAS_MATRIZ EQU {f}\n")
    print(f"msx2: nivel {nivel}, {f} filas")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
