#!/usr/bin/env python3
"""
analiza_perfil.py <perfil.txt> <juego.sym> <hz>

Lee el volcado de pruebas/perfil.tcl (muestras de PC cada 0,25 ms y marcas
de tiempo en puntos clave) y resume:
  - interrupciones VBLANK atendidas frente a las esperadas (perdidas por DI),
  - frames por vuelta del bucle principal (= tics de juego por segundo),
  - duracion de ACTUALIZAR_VRAM_FRAME y sus dos partes, en ciclos Z80,
  - reparto del tiempo de CPU por rutina (etiquetas de primer nivel).
"""
import bisect
import collections
import statistics
import sys

Z80 = 3579545


def main():
    fichero, symf, hz = sys.argv[1], sys.argv[2], float(sys.argv[3])
    sym = {}
    for l in open(symf):
        n, _, v = l.split()
        sym.setdefault(int(v, 16), n.rstrip(":"))
    tops = sorted((a, n) for a, n in sym.items() if "." not in n)
    dirs = [a for a, _ in tops]

    def nombre(pc):
        i = bisect.bisect_right(dirs, pc) - 1
        return tops[i][1] if i >= 0 else "?"

    S, T = [], collections.defaultdict(list)
    for l in open(fichero):
        k, v = l.split()
        if k == "S":
            S.append(int(v))
        else:
            T[k].append(float(v))

    dur = T["I"][-1] - T["I"][0]
    esperadas = dur * hz
    print(f"Duracion medida: {dur:.1f} s a {hz:g} Hz")
    print(f"Interrupciones atendidas: {len(T['I'])} de ~{esperadas:.0f} "
          f"({100 * (1 - len(T['I']) / esperadas):.0f}% perdidas)")

    frame = 1 / hz
    L = T["L"]
    d = [(b - a) / frame for a, b in zip(L, L[1:]) if (b - a) / frame < 30]
    c = collections.Counter(round(x) for x in d)
    print(f"Vueltas del bucle principal: {len(L)} -> {len(L) / dur:.1f} tics/s; "
          f"frames por tic: media {statistics.mean(d):.2f}, reparto {sorted(c.items())}")

    def tramos(a, b):
        out, j = [], 0
        tb = T[b]
        for t in T[a]:
            j = bisect.bisect_left(tb, t, j)
            if j < len(tb) and tb[j] - t < 0.5:
                out.append((tb[j] - t) * Z80)
        return out

    for a, b, txt in (("V", "C", "icono HUD / relleno LDIR"),
                      ("C", "E", "colores destello + volcado 3456 bytes"),
                      ("V", "E", "ACTUALIZAR_VRAM_FRAME completo")):
        x = tramos(a, b)
        if x:
            print(f"  {txt:40s} {statistics.mean(x):8.0f} ciclos "
                  f"({statistics.mean(x) / (Z80 * frame):.2f} frames), n={len(x)}")

    c = collections.Counter(nombre(p) for p in S)
    print("Reparto de CPU (muestras de PC):")
    for n, k in c.most_common(18):
        print(f"  {100 * k / len(S):6.2f}%  {n}")


if __name__ == "__main__":
    main()
