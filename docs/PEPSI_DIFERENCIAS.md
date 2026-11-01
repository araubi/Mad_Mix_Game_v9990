# The Pepsi Challenge (Topo / US Gold, 1988) frente a Mad Mix Game

Cinta comparada: `Pepsi Challenge The 1988Topo US GoldGBRUNCAS-.cas` (49 881 bytes),
contra la imagen original de Mad Mix reconstruida del desensamblado de raemca
(tag f0 del repo). Mismo cargador y misma estructura de cinta: MADMIX (BASIC),
LOGOTOPO.CM, LOAD (BASIC), LOAD.BIN (turbo, $E09C), TEST.BIN ($C350, busca la
RAM) y dos bloques sin cabecera: $1000 (20 992 bytes) y $8400 (23 360 bytes).

## Lo que cambia

- **Protagonista**: los sprites 0-11, 57 y 58-61 (comecocos normal y
  «bestia» en sus direcciones, y su muerte) pasan a ser la mascota de Pepsi:
  una bola con cara, manos y pies. El 63 (vacío en Mad Mix) trae un dibujo.
  Ver `comparativa_sprites.png` (arriba Mad Mix, abajo Pepsi).
  En la tabla de sprites, el byte de indicador de los sprites 0-2 y 7-9 pasa
  de 6 a 2.
- **Losetas**: 59, 60 y 62 (objetos del suelo: los que transforman al
  comecocos) y el mosaico 84-87 (la cara de comecocos de 2×2 que hay en el
  laberinto). Ver `losetas_distintas.png`.
- **Marcador**: el logo de Topo de abajo a la izquierda es el de Pepsi, y el
  icono de vidas es la mascota (`marco_caramelo_*`, `icono_vida`).
- **Fases**: desaparece la fase 1 de Mad Mix (la del mosaico del comecocos).
  La fase 1 de Pepsi es la 2 de Mad Mix y así sucesivamente: 14 fases (el
  bucle compara con 15 en vez de 16). Los laberintos son idénticos byte a byte.
- **Textos en inglés**: 1 KEYBOARD, 3 REDEFINE KEYS, 0 START, PAUSE, FIRE,
  UP/DOWN/LEFT/RIGTH (sic), SPACE, LEVEL, IN THE NEXT... EXTRA, GAME OVER,
  BRUTE (por BESTIA), GOMINOLAS (por COMILONAS). Créditos: «PROGRAM: RAFAEL
  GOMEZ», «GRAPHICS:», «MUSIC:», «TOPO SOFT -1988-» (Mad Mix pone «RAPHAEL
  GOMEZZZ..», «GRAPHICOS BY», «MUSIC-A BY», «TOPOSHOW -1988-»).

## Lo que no cambia

Logo animado de Topo (idéntico), portada/pantalla de carga, fuente, música y
efectos, demos, enemigos (fantasmas, mariquita, «repugnante»), las
transformaciones (avión, obras, hipopótamo, tanque), los 400/600 puntos y las
demás losetas. El código es el mismo con los datos recolocados.
