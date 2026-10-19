#!/usr/bin/env python3
"""ritmo.py <hz> <N> <etiqueta:perfil.txt>... -- ritmo real del juego a partir de las
marcas L: tics por segundo, reparto de frames entre tics y tics que empiezan tarde
respecto a la rejilla ideal de N frames (retraso acumulado)."""
import collections, sys
hz, N = float(sys.argv[1]), int(sys.argv[2])
print(f"{'version':9s} tics  tics/s  frames entre tics            % tics con retraso   retraso max")
for arg in sys.argv[3:]:
    tag, f = arg.split(":", 1)
    L = [float(l.split()[1]) for l in open(f) if l.startswith("L ")]
    # tramos continuos (sin pausas de presentacion de nivel)
    tramos, cur = [], [L[0]]
    for a, b in zip(L, L[1:]):
        if (b - a) * hz > 15: tramos.append(cur); cur = [b]
        else: cur.append(b)
    tramos.append(cur)
    d = collections.Counter(); n = 0; tiempo = 0; tarde = 0; peor = 0
    for t in tramos:
        for a, b in zip(t, t[1:]): d[round((b - a) * hz)] += 1
        n += len(t) - 1; tiempo += t[-1] - t[0]
        for k, x in enumerate(t):
            r = round((x - t[0]) * hz) - k * N
            if r > 0: tarde += 1
            peor = max(peor, r)
    print(f"{tag:9s} {n:4d}  {n / tiempo:6.2f}  {str(sorted(d.items())):28s} {100 * tarde / max(1, n):5.0f}%   {peor:4d} frames")
