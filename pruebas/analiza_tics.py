#!/usr/bin/env python3
"""analiza_tics.py <perfil.txt> <juego.sym> <hz> <frames_por_tic>
Desglosa cada tic (entre dos marcas L) por grupos de rutinas usando las
muestras de PC (cada 0,25 ms) y compara los tics a tiempo con los que se pasan."""
import bisect, collections, sys
f, symf, hz, N = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
sym = {}
for l in open(symf):
    n, _, v = l.split(); sym.setdefault(int(v, 16), n.rstrip(":"))
tops = sorted((a, n) for a, n in sym.items() if "." not in n); dirs = [a for a, _ in tops]
def nombre(pc):
    i = bisect.bisect_right(dirs, pc) - 1; return tops[i][1] if i >= 0 else "?"
GRUPOS = [("scroll_h", ("SCROLL_DERECHA", "SCROLL_IZQUIERDA")),
          ("scroll_v", ("APLICAR_DESPLAZAMIENTO_LATERAL", "SCROLL_ARRIBA", "SCROLL_ABAJO")),
          ("franja_nueva", ("SCROLL_LOSETA_BUFFER_VRAM", "COPIAR_LOSETA_FASE_A", "COPIAR_LOSETA_FASE_B",
                            "DIBUJAR_FILA_LOSETAS_BUFFER_VRAM", "MAPEAR_LOSETA_A_GRAFICO")),
          ("volcado", ("VOLCAR_FILA_CARACTERES", "ACTUALIZAR_VRAM_FRAME_OPT", "FILVRM", "SETVRAM")),
          ("espera", ("ESPERAR_TIC", "WAIT_VBLANK_OPT")),
          ("sonido_isr", ("ENTRADA_INTERRUPCION_VBLANK", "DESPACHAR_EFECTO_SONIDO", "VOLCAR_REGISTROS_PSG",
                          "COMBINAR_Y_ESCRIBIR_CANAL", "PROCESAR_CANAL_PSG", "ACTUALIZAR_MEZCLADOR_CANAL",
                          "APLICAR_ENVOLVENTE_RUIDO", "GESTIONAR_FRAME_OPT"))]
def grupo(n):
    for g, ns in GRUPOS:
        if n in ns: return g
    if "ACTOR" in n or "MASCARA" in n or "PATRON" in n or "DESPLAZADA" in n: return "actores"
    return "logica"
frame = 1 / hz; ms = 0.25e-3
tics = []; cur = None; tL = None
for l in open(f):
    k, v = l.split(None, 1)
    if k == "H": continue
    if k == "L":
        t = float(v)
        if cur is not None: tics.append(((t - tL) / frame, cur))
        cur = collections.Counter(); tL = t
    elif k == "S" and cur is not None:
        cur[grupo(nombre(int(v)))] += 1
tics = [x for x in tics if x[0] < 20]
def resumen(sel, txt):
    if not sel: return
    m = collections.Counter()
    for _, c in sel: m.update(c)
    print(f"{txt}: {len(sel)} tics")
    for g in [g for g, _ in GRUPOS] + ["actores", "logica"]:
        print(f"   {g:13s} {m[g] * ms / len(sel) / frame:5.2f} frames")
a_tiempo = [x for x in tics if round(x[0]) <= N]; pasados = [x for x in tics if round(x[0]) > N]
resumen(a_tiempo, "A tiempo"); resumen(pasados, "Pasados")
# combinaciones de scroll en los pasados
def tipo(c): return "+".join(g for g in ("scroll_h", "scroll_v") if c[g] > 4) or "sin scroll"
print("Tipo de scroll  a_tiempo / pasados:")
ta = collections.Counter(tipo(c) for _, c in a_tiempo); tp = collections.Counter(tipo(c) for _, c in pasados)
for k in sorted(set(ta) | set(tp)): print(f"   {k:20s} {ta[k]:4d} / {tp[k]:4d}")
