#!/usr/bin/env python3
"""compara_estado.py <a.txt> <b.txt>: compara tic a tic las huellas H (PERF_HASH=1)
de dos ejecuciones de la demo determinista (ROM de pruebas)."""
import sys
def h(f): return [l.split()[1:] for l in open(f) if l.startswith("H ")]
a, b = h(sys.argv[1]), h(sys.argv[2]); n = min(len(a), len(b))
nombres = ["variables", "matriz", "buffer"]
for i, nom in enumerate(nombres):
    d = [k for k in range(n) if len(a[k]) > i and len(b[k]) > i and a[k][i] != b[k][i]]
    print(f"{nom:10s}: {n} tics, {len(d)} distintos" + (f" (primero en el tic {d[0]})" if d else ""))
