#!/usr/bin/env python3
"""analiza_carga.py <hz> <N> <etiqueta:perfil.txt> ...
Carga real de cada tic (duracion menos el tiempo esperando) en frames, a partir
de las marcas L y las muestras de PC; sirve para comparar versiones sobre la
misma partida grabada (modo demo). Un tic cabe si su carga es < N frames."""
import bisect, sys
hz, N = float(sys.argv[1]), int(sys.argv[2])
KMAX = 10**9  # se recorta a los tics comunes a todas las versiones
sym = {}
for l in open("/home/claude/madmix/v9990/build/juego.sym"):
    n, _, v = l.split(); sym.setdefault(int(v, 16), n.rstrip(":"))
tops = sorted((a, n) for a, n in sym.items() if "." not in n); dirs = [a for a, _ in tops]
ESPERA = {"ESPERAR_TIC", "WAIT_VBLANK_OPT", "WAIT_VBLANK"}
def nombre(pc):
    i = bisect.bisect_right(dirs, pc) - 1; return tops[i][1]
res = {}
for arg in sys.argv[3:]:
    tag, f = arg.split(":", 1)
    cargas = []; esp = 0; tL = None
    for l in open(f):
        k, v = l.split(None, 1)
        if k == "L":
            t = float(v)
            if tL is not None:
                d = (t - tL) * hz
                cargas.append(d - esp * 0.25e-3 * hz if d < 20 else None)
            tL = t; esp = 0
        elif k == "H":
            continue
        elif k == "S" and tL is not None and nombre(int(v)) in ESPERA:
            esp += 1
    res[tag] = cargas
K = min(len(c) for c in res.values())
print(f"Comparacion sobre los primeros {K} tics de la demo (misma entrada grabada)")
print(f"{'version':10s} tics  carga media  p90   p99   max   tics que no caben en {N} frames")
for tag, cargas in res.items():
    cargas = [x for x in cargas[:K] if x is not None]
    c = sorted(cargas); q = lambda p: c[min(len(c) - 1, int(p * len(c)))]
    over = sum(1 for x in c if x > N - 0.05)
    print(f"{tag:10s} {len(c):4d}  {sum(c)/len(c):6.2f}      {q(.9):5.2f} {q(.99):5.2f} {c[-1]:5.2f}  {over} ({100*over/len(c):.0f}%)")
