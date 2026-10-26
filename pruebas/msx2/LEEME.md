# MSX2, fase 0: prueba de velocidad del V9938 (2026-10-26)

`python3 pruebas/msx2/datos.py [nivel]` saca de `build/ram_*.bin` las
losetas y actores originales a 4 bpp; luego, desde `pruebas/msx2/`,
`sjasmplus velocidad2.asm` (o `-DHZ60`) deja `build/msx2/velocidad2.rom`
(ROM de 32 KB, MSX2 con 128 KB de VRAM).

- `velocidad.asm`: recompone cada tic las 130 losetas (HMMM 16x16), 10
  actores (LMMM con TIMP) y copia la ventana. 10 frames por tic a 50 Hz:
  no vale.
- `velocidad2.asm`: el fondo es un anillo de 16x16 losetas en la página 3;
  por tic solo se dibujan las losetas nuevas, se copia la ventana del
  anillo a la página oculta (1-4 HMMM) y se ponen los actores encima.
  Barra bajo la ventana: 16 px por frame del tic anterior; la marca
  blanca es el presupuesto.

Medido en openMSX (C-BIOS MSX2, cámara 4 px por tic, 140-150 tics):

| | 50 Hz (presupuesto 5) | 60 Hz (presupuesto 6) |
|---|---|---|
| fondo + ventana | 3 frames | 3-4 frames |
| + 10 actores de 24x24 | 5 (85 %), 6 (15 %) | 6 (78 %), 7 (22 %) |

Resultado en RAM: TICS ($C100) e HISTOGRAMA ($C102, 16 x 16 bits).
