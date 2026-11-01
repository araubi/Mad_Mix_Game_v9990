# Gráficos del remake de Mad Mix Game: qué hay y dónde

Material de Guantxip, grafista del remake (2013-2015), entregado por araubi el 2026-10-21:
64 ficheros dentro de una carpeta `mad mix game remake/`. En este repositorio solo
están los que usa la build, en `graficos/remake/`.

## Resumen

- Hay todo lo necesario para la versión V9990: portada, maqueta de pantalla, los 15 mapas de nivel, las hojas de losetas con su paleta y la hoja completa de sprites con fuente y marcador.
- Todo está pensado para 16 colores por pantalla, con el color 0 (magenta FF00F6) como transparente. Encaja con el modo P1 del V9990, que tiene 4 bpp y 16 colores por capa.
- Los mapas coinciden con los niveles del juego: cada `madmixmapfaseN.png` tiene 32 columnas de losetas de 16×16 y el mismo número de filas que la matriz del nivel N (cabecera, cuerpo y pie).
- Las losetas nuevas no sustituyen una a una a las 91 originales. El grafista ha redibujado las paredes con más variedad, de modo que un mismo índice original lleva losetas nuevas distintas según dónde esté, y al revés. La versión V9990 necesitará por eso un mapa de losetas propio por nivel para el dibujo, y la matriz original seguirá sirviendo para la lógica (colisiones, bolas). Esto se ha medido en los 15 niveles; solo el 12 sale casi uno a uno.

## Ficheros

| Fichero | Qué es | Formato |
|---|---|---|
| `portada.png`, `portada.bmp`, `portada.psd` | Portada nueva (comecocos gigante, fantasmas) | 256×212, 62 colores |
| `portada.SC5` | La misma portada en SCREEN 5 (16 colores), lista para BLOAD | BSAVE de 0000h a 769Fh, con la paleta en 7680h |
| `portada.SC8` | La misma en SCREEN 8 (256 colores) | BSAVE de 0000h a D3FFh |
| `portada.SCC` | La misma en SCREEN 12 (YJK) | BSAVE de 0000h a D3FFh; no es igual al SC8 |
| `portada original msx1.png` | Portada del juego original, como referencia | 256×192 |
| `madmix.png` / `madmix2.png` (+ `.psd`) | Maqueta de la pantalla de juego con marco, marcador, vidas y puntos. Abajo lleva la tira de 16 colores | 256×212, 16 colores. Las dos se diferencian solo en la caja oscura de arriba a la izquierda (vacía o rellena) |
| `madmixmapfase1..15.png` (+ `.psd`) | Mapa completo de cada nivel con el arte nuevo; incluye las bolas y algún personaje en su posición de salida | 512 × (16 × filas), 11-15 colores |
| `paletafaseN.png` | Losetas del nivel N: la fila de arriba es la paleta (16 colores de 8 px), y desde y=16 vienen losetas de 16×16, 8 por fila | 128 × 64-144 |
| `paletafase1-11-15`, `2-10`, `4-12`, `5-7-13`, `6-14` | Hojas combinadas para los niveles que comparten paleta: la unión de las losetas de esos niveles | 37-57 losetas |
| `or fase 1.png` | Hoja completa de sprites de 16×16, ver abajo | 512×256 |
| `sprites1.png` | Versión anterior y reducida de la hoja de sprites, sin las capas ni la fuente | 256×256 |
| `madmixmap.png` | Mapa de los 15 niveles de la versión Spectrum, de Pavero (2007, maps.speccy.cz). No es del grafista; solo sirve de referencia | 4598×1412 |

Las capas de los PSD tienen nombres genéricos ("Capa 0", "Capa 1"…). La única con nombre propio es «bola hundida», en la fase 5. Los PNG son los PSD ya aplanados.

## Niveles: mapa, hoja de losetas y paleta

Las filas se han comprobado contra `TABLA_NIVELES` y salen iguales que en el juego:

| Nivel | Filas | Hoja propia | Hoja combinada |
|---|---|---|---|
| 1 | 28 | paletafase1 (35 losetas) | 1-11-15 (57) |
| 2 | 21 | paletafase2 (28) | 2-10 (37) |
| 3 | 22 | paletafase3 (30) | — |
| 4 | 21 | paletafase4 (33) | 4-12 (38) |
| 5 | 22 | paletafase5 (35) | 5-7-13 (42) |
| 6 | 24 | paletafase6 (34) | 6-14 (39) |
| 7 | 25 | paletafase7 (37) | 5-7-13 |
| 8 | 21 | paletafase8 (33) | — |
| 9 | 24 | paletafase9 (37) | — |
| 10 | 23 | paletafase10 (27) | 2-10 |
| 11 | 27 | paletafase11 (39) | 1-11-15 |
| 12 | 25 | paletafase12 (24) | 4-12 |
| 13 | 27 | paletafase13 (37) | 5-7-13 |
| 14 | 29 | paletafase14 (39) | 6-14 |
| 15 | 24 | paletafase15 (29) | 1-11-15 |

Entre todas las hojas hay 232 losetas distintas. Las celdas de los mapas que no aparecen en su hoja son el fondo de fuera del laberinto, las bolas sobre el suelo y los personajes dibujados encima.

**La paleta.** Los colores 1, 2, 4 y 11 cambian de un nivel a otro, porque son los cuatro tonos de las paredes y el suelo. Los otros 11 son fijos en todas las fases y coinciden con los de los sprites:
- 0: transparente (FF00F6)
- 3: 4CDDFE
- 5: 29D929
- 6: EFB0F1
- 7: FCFC6F
- 8: CB3107
- 9: 5D5D5D
- 10: 22AF22
- 12: 286FB2
- 13: FFFFFF
- 14: B7B7B7
- 15: 000000

Esto viene bien para el V9990: una paleta fija para los sprites y solo cuatro entradas que cambian al empezar cada nivel. Por niveles:

| Niveles | Colores 1, 2, 4 y 11 |
|---|---|
| 1, 11 y 15 (arena) | FFEBA0 E5D28E BAAA73 4A442E |
| 2 y 10 (verde agua) | 99E9D3 7FBEAD 5B8B7D 16201F |
| 3 | D8B493 B0947A 816B58 1D1A15 |
| 4 y 12 (azul) | 7DC1FF 6497C9 3F6588 0F2236 |
| 5, 7 y 13 (naranja) | FFB94E B8812F 351E01 76583F |
| 6 y 14 (rosado) | FFBDA0 E5A88E BA8873 300800 |
| 8 (cian) | 4EF7FF 00DEE7 003635 06AF9C |
| 9 (morado) | CE88DD 8F5C9A 321F35 B576C4 |

## Sprites (`or fase 1.png`)

**Cómo está organizada la hoja.** Hay celdas de 16×16 sobre fondo magenta. Cada sprite aparece en tres filas:
1. el dibujo final;
2. y 3. sus dos capas de color, pensadas para los sprites del MSX2, que superponen dos sprites de un color y mezclan los colores con OR.

Abajo hay una leyenda «+ =» que explica cómo se mezclan. Para el V9990, que tiene sprites de 16 colores, basta con la primera fila.

**Qué personajes y objetos hay:**
- Fantasmas cian y blancos, de frente y de lado.
- El comecocos: animación de boca, cara y caras de risa, encogiéndose, y la versión roja.
- Hipopótamos de frente, de espaldas y de lado.
- Tanques, aviones, ranas verdes y mariquitas.
- Bonos 400 y 600, el plátano, el cofre y el helicóptero con el comecocos.

**Marcador y fuente:** dígitos verdes del 0 al 9, la fuente blanca de A a Z con números y signos, el logo y el marco.

**Paleta de los sprites:** usan los colores fijos de la paleta de losetas, más 4A442E y FFEBA0.

## Detalles para el grafista (menores, no bloquean)

- `paletafase2.png` tiene el color 11 = 547876, pero `paletafase2-10.png` y la 10 tienen 16201F.
- En cada mapa, el fondo de fuera del laberinto usa un color que no está en su paleta; en el nivel 2, por ejemplo, 16201F. Además, las bolas y personajes dibujados encima usan casi-blanco FEFEFE y amarillo EDED2D en vez de FFFFFF y FCFC6F. Al convertir habrá que llevarlos a los colores de la paleta.
- `or fase 1.png` tiene 176 píxeles en FEFEFE en lugar de FFFFFF, y `sprites1.png` tiene 2 píxeles en DFDF2F.
- `madmixmapfase1.png` mide 470 px de alto: tiene 16 px de más arriba y 6 abajo respecto a las 28 filas del nivel. Los demás mapas encajan exactos.
