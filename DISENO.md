# Mad Mix Game v9990 — diseño

Reescritura del subsistema gráfico de *Mad Mix Game* (Topo Soft, 1988)
para el VDP **Yamaha V9990** (cartucho GFX9000), manteniendo la lógica
de juego original. Plataforma: **MSX1 con 64 KB de RAM + GFX9000**,
distribuido como **megaROM ASCII16**.

## 1. Punto de partida

- Base: desensamblado completo de Rafael Eduardo Martín Candial
  (`github.com/raemca/MSX_MadMixGame`), que compila byte a byte.
- Correcciones de la v2.0 de Manuel Pazos (2013), adoptadas desde el
  principio:
  - buffer de nivel en `$FC50` (en vez de `$FC60`) en los 5 sitios — bug
    del contador de bolitas del nivel 13 (ya aplicado en la base);
  - pila en `$F2FF` (en vez de `$0FFF`) en `INICIO`, `$8F26`.
  
  La imagen RAM resultante coincide con el CAS de Pazos salvo los 3
  bytes `$28ED-$28EF`, que la base ya documenta como contenido ajeno
  (zona de variables).

## 2. Por qué el juego encaja bien en el V9990

| Original (TMS9918, SCREEN 2) | V9990 (modo P1, 256×212) |
|---|---|
| Laberinto de 32×(≤29) losetas de 16 px = máx. 512×464 px, guardado en `$FC50` | Cabe entero en una capa P1 (64×64 patrones de 8×8 = 512×512 px): se dibuja una vez al cargar el nivel |
| Scroll por software de 4 px (`RLD`/`RRD` sobre `BUFFER_LOSETAS_TRABAJO`, `$DE04`) + volcado de 3,4 KB a VRAM cada frame (`ACTUALIZAR_VRAM_FRAME`) | Registros de scroll por hardware de la capa B: unos pocos bytes por frame |
| Actores dibujados por software (máscara AND + OR, desplazamiento sub-carácter, volteo), máx. 10 por frame (`MOTOR_ACTORES` + `COMPONER_ACTORES_EN_BUFFER`) | Sprites hardware de 16×16 a 16 colores: 125 en pantalla, 16 por línea; el volteo se resuelve con patrones ya volteados en VRAM |
| Marco de caramelo y HUD en la tabla de patrones/color | Capa A (delante), fija, con el color 0 transparente donde se ve el laberinto |
| Paleta fija de 15 colores | Paleta de 64 entradas de 15 bits (se empieza con la del TMS) |
| Ventana de juego de 24×18 caracteres (192×144 px) en (32,16) | Al principio la misma ventana, para no tocar cámara ni recortes; ampliarla es una mejora posterior |

Comer una bolita, que en el original redibuja una loseta en el buffer,
pasa a ser escribir 4 entradas de la tabla de nombres de la capa B.

## 3. Memoria

**Z80 (todo en RAM, como el original):**

| Zona | Uso |
|---|---|
| `$0000-$0FFF` | RAM baja (`$0038` = ISR del juego, `$0500` = cursor de máscaras de actores, que desaparece con los sprites) |
| `$1000-$64FF` | cuerpo de `MADMIX.SCR` (portada, colisión, ítems, niveles, menú) |
| `$6500-$83FF` | libre en el original (~7,9 KB); `$6500-$6BFF` = `optimizaciones.asm`, el resto para el código del V9990 |
| `$7FF0-$83B0` | filas traspuestas del volcado (`TRASPUESTA`, 5 × 192 bytes, solo en ejecución) |
| `$8400-$DDA0` | motor (`MADMIX1.BIN`) |
| `$DE04-...` | `BUFFER_LOSETAS_TRABAJO` — innecesario con el V9990, queda libre |
| `$F2FF` hacia abajo | pila (Pazos) |
| `$FC50-$FFEF` | matriz del nivel activo |

**ROM ASCII16:** banco 0 = cabecera y cargador; bancos 1..n = imagen
RAM del juego, logo y, en fases posteriores, los gráficos ya
convertidos al formato del V9990. Estos gráficos se suben a la VRAM
del V9990 (512 KB) durante el arranque, así que después de arrancar
no se vuelve a leer la ROM.

**Arranque:** detecta el slot del cartucho y el de la RAM de la página 3
(se usa el mismo slot para las páginas 0-2 y se comprueba antes),
reproduce el `COLOR 1,1,1:SCREEN 2` del BASIC de cinta, muestra el
logo de Topo, copia el juego en fragmentos de 2 KB a través de un
buffer en `$E800`, deja las 4 páginas en RAM y salta a `START`
(`$8400`).

## 4. Fases

| Fase | Contenido | Estado |
|---|---|---|
| **F0** | ROM del juego original (TMS9918) con el cargador definitivo y los fixes de Pazos — referencia para comparar | hecha y probada en openMSX (C-BIOS MSX1): logo, portada, menú y partida |
| **F0b** | Juego base optimizado (MSX1, TMS9918): volcado fuera de la ISR, tic fijo de 5/6 frames, sin el `LDIR` de relleno, volcado desenrollado — ver `ANALISIS_RENDIMIENTO.md` | hecha y medida en openMSX a 50 y 60 Hz |
| **F0c** | F0b + espejo de actores con tabla, desplazamiento sub-píxel 6 en 2 pasos, paso fijo con recuperación de un frame; pruebas deterministas (`--pruebas`, huellas por tic) | hecha; idéntica píxel a píxel a f0b en la demo |
| **f0e / f1c** | Volcado sincronizado con el haz (`volcado_haz.asm`): cada fila se escribe detrás del haz (marca con el indicador de quinto sprite), las filas que caen en el borde se trasponen antes y van con OUTI, la música se aplaza al final del volcado. Quita el corte que se veía al hacer scroll | hecha; demo idéntica tic a tic a f0d/f1b; sin cortes a 50 Hz, a 60 Hz las 4 últimas filas van un frame tarde |
| **F1** | Detección e inicialización del V9990 en P1, paleta, conversión de las 91 losetas a patrones de 4 bpp, laberinto en la capa B y scroll por hardware enganchado a la cámara | hecha (`v9990.asm`); probada en openMSX con GFX9000 a 50 y 60 Hz, ver §6 |
| **F2** | Actores como sprites (64 patrones fuente + versiones volteadas); retirar `MOTOR_ACTORES` y el volcado por frame | — |
| **F3** | Capa A: marco de caramelo, marcador, vidas, icono de nivel, destellos del HUD | — |
| **F4** | Portada, menú, créditos, presentación de nivel y Game Over en el V9990 | — |
| **F5** | Limpieza (código TMS muerto), sin pantalla del TMS; mejoras opcionales (ventana mayor, scroll más fino, colores nuevos) | — |

Durante F1-F4 la pantalla del TMS9918 sigue funcionando en paralelo, de
modo que se pueden comparar las dos salidas una al lado de la otra (en
openMSX, cambiando de fuente de vídeo).

## 5. Pendiente de confirmar

- Conversión de coordenadas de los actores (columna 4-116 de la
  ventana) a posición de sprite del V9990 (F2). La del laberinto ya
  está resuelta (§6).
- Si `COMPONER_ACTORES_EN_BUFFER` y el cursor de `$0500` tienen otros
  usuarios fuera del dibujado de actores, antes de retirarlos.
- Si `REINICIO_SLOT_DD82`/`REUBICADOR_REINICIO_JUEGO` (conmutan slots
  con un valor fijo `$55`) se usan alguna vez: con la ROM no deben
  ejecutarse.

## 6. F1: el laberinto en el V9990 (`src/juego/v9990.asm`)

**Arranque.** El cargador llama a `V9_INICIAR` (`$6C00`) con el juego
ya en RAM. Si R#15 del V9990 no se puede leer y escribir no hay
GFX9000 y no se hace nada más: el juego es idéntico a f0c. Si lo hay:
reinicio, modo P1 (R#6 = `$05`, R#7 = PAL si la máquina va a 50 Hz),
paleta 0-15 con los colores del TMS9918, y conversión de las 91
losetas.

**VRAM (direcciones del modo P1):**

| Zona | Uso |
|---|---|
| `$00000` | generador de la capa A: patrón 0 transparente, patrón 1 negro |
| `$40000` | generador de la capa B: la loseta t a 4 bpp en x = (t mod 16)·16, y = (t div 16)·16 de un mapa de 256 px de ancho (patrones p, p+1, p+32, p+33 con p = (t div 16)·64 + (t mod 16)·2) |
| `$7C000` | nombres de la capa A: máscara negra fuera de la ventana de 24×18 caracteres en (32,24) |
| `$7E000` | nombres de la capa B: la matriz entera, loseta (r,c) en `$7E000 + r·256 + c·4` |

**Colores.** Los píxeles de las losetas valen 1 (fondo) y 2 (tinta);
la capa B usa el desplazamiento de paleta 16, así que son las
entradas 17 y 18, que `V9_TIC` carga con el color que el juego pinta
en la ventana del TMS (`CONSULTAR_COLOR_VDP` de
`REGISTRO_NIVEL_ICONO_HUD`). Se usan los colores del TMS9918 tal cual
(tabla clásica de TI); el rediseño de colores queda para F5.

**Losetas que cambian.** `SOMBRA_MATRIZ` (`$7C50`, la matriz − `$8000`)
guarda lo que ya hay en la capa B. En cada tic, `V9_TIC` (llamado desde
`WAIT_VBLANK_OPT`, tras el volcado al TMS) compara la zona visible
(10 filas × 13 columnas) y una fila más en rotación, y escribe en la
VRAM solo las losetas distintas. `CARGAR_NIVEL` avisa con un parche
del mismo tamaño (`V9_CARGAR_NIVEL`) y el tic siguiente compara la
matriz entera. Así no hace falta localizar cada sitio del juego que
cambia una loseta (bolitas, bola de poder, mariquita...).

**Scroll.** La esquina de la ventana del TMS es el píxel
(L·4, H·4) del laberinto, con (L, H) = `REGISTRO_NIVEL_POSICION_COMECOCOS`
(comprobado en 175 tics de la demo contra `BUFFER_LOSETAS_TRABAJO`, sin
ninguna excepción). El scroll de la capa B es esa esquina menos (32,24).
Se escribe en la interrupción de fin de pantalla del propio V9990
(`V9_ISR`, instalada en `$0038` delante de la del juego): si se escribe
el scroll vertical con la imagen en curso, el V9990 parte la pantalla
por esa línea.

**Coste.** `V9_TIC` tarda ~0,19 frames por tic (mediana; 8 frames el
tic en que se carga un nivel). En la demo a 50 Hz salen un 3 % menos
de tics por segundo que en f0c, porque la pantalla del TMS sigue
funcionando entera. En F2 desaparecen el volcado y los actores del TMS
cuando hay V9990, y eso sobra para compensarlo.

**Verificación (openMSX, C-BIOS MSX1 a 60 Hz y MSX1 EU a 50 Hz):**
- Sin GFX9000, la demo determinista (`--pruebas`) es idéntica a f0c
  tic a tic: variables, matriz y buffer.
- Con GFX9000, el estado del juego también es idéntico tic a tic
  (solo arranca unos tics más tarde).
- La capa B coincide con la matriz en todas las muestras (como mucho
  4 losetas pendientes, las que cambian ese mismo tic).
- Capturas de las dos salidas: el contenido de la ventana coincide
  píxel a píxel salvo los actores, que llegan en F2.

## 7. F2: versión completa en el V9990 con los gráficos del remake (2026-10-21)

Con un GFX9000 toda la imagen sale por el V9990 y el TMS no recibe el
volcado de la ventana. Sin GFX9000 el juego es idéntico a f1c (comprobado
con `compara.sh` y las ROM `--pruebas`: capturas idénticas de 22 a 54 s).

**Gráficos.** `tools/graficos.py` convierte `graficos/remake/` (del
grafista, entregados por Rubén) a `build/v9_*.bin` y `build/v9_datos.inc`;
`build.py` lo ejecuta entre dos pasadas de sjasmplus. El cargador de la ROM
(`V9_SUBIR`, `src/rom/rom.asm`) sube los fragmentos a la VRAM antes de
arrancar.

- Los mapas del grafista están girados en horizontal respecto a la
  matriz; `alinear()` busca el giro de columnas de cada nivel (1: 3;
  5 y 12: 0; 7: 13; resto: 31). Coincidencia del 85 al 100 %.
- Bloque de 4 KB por nivel en $20000: por celda (valor inicial, loseta del
  dibujo, suelo de debajo), paleta de la capa B en +$E80 y loseta de
  respaldo por valor en +$F00. En partida: valor inicial → dibujo; valor
  comodín (bola comida) → suelo; otro → respaldo. La chispa de la puerta de
  los fantasmas ($38/$39) usa la loseta del nivel dada la vuelta.
- 222 losetas (capa B, $40000) y 161 patrones de sprite ($18000).

**Paletas.** 0-15 colores del TMS (espejo), 16-31 laberinto del nivel,
32-47 sprites, 48-63 marco o portada. Los textos sobre la ventana (FASE,
READY?, ESTÁS FRITO) se pasan a la paleta del marco con `V9_TMS_A_MARCO`;
los colores del TMS que no tienen uno parecido en el marco ocupan sus
entradas libres.

**Modos** (`V9_MODO`): espejo (menús, créditos, redefinir teclas: copia de
la pantalla del TMS fila a fila, solo las filas cuya suma cambia; al entrar
se ponen en negro y cada fila aparece al copiarla), juego (laberinto,
sprites, marco y marcador nuevos) y portada.

**Interrupciones.** `V9_ISR` atiende el fin de pantalla del V9990 (scroll
y tabla de sprites). Si el juego estaba en un HALT, vuelve al mismo HALT
para que las pausas sigan contando solo los VBLANK del TMS. Para no
confundir «en el HALT» con «justo detrás del HALT» (la ISR del TMS vuelve
a la instrucción siguiente y, si el V9990 interrumpe en ese momento,
parece un HALT a medias y la pausa no avanza nunca: así se colgaba en
«FASE 1»), con V9990 la ISR del TMS vuelve por `V9_ISR.TRAS_TMS`, que
atiende allí un fin de pantalla pendiente del V9990.

**Pendiente.** Probar en máquina real; los menús tardan algo más de un
segundo en copiarse (hay pocos puntos seguros donde leer el TMS); los
fantasmas usan todos el mismo dibujo del grafista.

## 8. f2b: fantasmas, logo de Topo y pantalla de carga (2026-10-22)

- Fantasmas: estaban cambiados el dibujo normal y el girado del grafista
  (`SPRITES` en `tools/graficos.py`).
- Logo de Topo en el V9990: sus `WRTVRM`/`LDIRMV` pasan por las entradas
  `$E000`/`$E003` del cargador, que escriben en copias en RAM y marcan las
  celdas cambiadas; en las 5 pausas del logo (`HALT` parcheados) se
  redibujan en el V9990 (`LOGO_*` en `src/rom/rom.asm`). Va sincronizado
  con el TMS, algo más lento (7,65 s frente a 6,03 s).
- Con GFX9000 el TMS enseña la pantalla de carga original: en MSX2 fija
  (guardada en la VRAM alta del V9938), en MSX1 hasta que el juego pinta.

## 9. f2c: opción 3, The Pepsi Challenge (2026-10-22)

`src/juego/pepsi.asm`. La tecla 3 del menú alterna Mad Mix Game y The
Pepsi Challenge (versión inglesa de Topo / US Gold): nivel inicial 2
contado como 1 (`NIVEL_INICIAL`, `NIVEL_VUELTA`, `NUMEROS_NIVEL_BASE`) y
la mascota de Pepsi (`data/pepsi/sprites_pepsi.bin`, de la cinta).

- TMS: los sprites se cambian con un XOR en tramos (`PEPSI_DELTA`, $7700,
  generado por `graficos.py`), después de enderezar los que el motor tiene
  dados la vuelta en su sitio (bits 6-7 del indicador).
- V9990: `V9_META_ELEGIR` elige `V9_META_PEPSI` (partes de 16×16 de la
  mascota en amarillo y negro, misma rejilla de 24×24 que el TMS).
- La carga de la ROM empieza en el banco 0 ($5800) para seguir en 256 KB.

## 10. f2d: arreglos de Rubén a f2c (2026-10-22)

- **Comecocos hacia la izquierda en el V9990.** Reflejado, el motor del
  TMS lo dibuja además desplazado a la izquierda tantos píxeles como
  columnas libres tiene a la derecha (bits 0-2 del indicador, 6 en el
  comecocos). `original()` no lo tenía en cuenta y el sprite iba 6 píxeles
  a la derecha: parecía no llegar al borde y comerse los cocos antes de
  tiempo.
- **Animación de The Pepsi Challenge.** Sus subtablas de dirección son
  otras: hacia arriba anda (sprites 64 y 65, que Mad Mix no tiene; usa el
  6 quieto) y con la bola de poder baja en otro orden (10, 11, 57, 11 en
  lugar de 10, 57, 11, 57). El motor solo tiene 64 sprites, así que el 64
  va en el 63 (el nulo, sin usar) y el 65 es el 64 reflejado con 5
  columnas libres (iguales salvo un píxel): arriba = $3F, $06, $BF, $06.
  Al alternar se aplican tres XOR (`PEPSI_XOR`): subtablas
  (`PEPSI_SUBTABLAS`, ambos chips), indicadores y puntero del 63
  (`PEPSI_INDICADORES`, en $DDA1, libre detrás del motor) y sprites
  (`PEPSI_DELTA`). En el TMS el 63 apunta a `PEPSI_SPR63` ($7F60).
- **Comecocos rojo hacia arriba (V9990).** El juego usa el sprite 6 hacia
  arriba también con la bola de poder; con `MODO_ESPECIAL` = 1,
  `V9_META_ELEGIR` da el dibujo rojo del grafista (`V9_META_ROJO_ARRIBA`).
- **Cocos que no se ven.** El mapa del grafista del nivel 1 no trae tres
  cocos junto a la salida del comecocos (y falta algún objeto suelto en los
  niveles 6, 8, 11 y 15). Si una celda tiene suelo en el mapa pero su valor
  casi siempre lleva objeto, se dibuja la loseta de ese valor sobre el
  suelo más parecido.
- Sin cambiar de juego, la partida en el TMS es idéntica a f1c (C-BIOS
  MSX1 y MSX2); alternar dos veces deja la RAM como estaba.
- **Fantasmas blancos hacia arriba (f2e, V9990).** La tabla de animación
  de los fantasmas vulnerables (`TABLA_ANIMACION_PELMAZOIDE` + 38) usa
  hacia arriba los mismos sprites que los normales (31 y 32, azules). Con
  el V9990, `V9_FANTASMAS_BLANCOS` los cambia al arrancar por el 31 y el 32
  reflejados, que en `V9_META` son los dibujos blancos de espaldas del
  grafista. En el TMS no cambia nada.
- **Fantasmas de colores y mascota roja (f2f, V9990).** Como en Pac-Man:
  rojo, rosa, cian (el del grafista) y naranja, según la entrada del
  fantasma en `TABLA_ITEMS_PELMAZOIDE` (and 3). `V9_INDICADORES_ACTOR`
  guarda ese número en los bits 0-1 de los indicadores del actor y
  `V9_META_ELEGIR` elige las partes (`V9_META_F_ROJO`, `V9_META_F_NARANJA`:
  los mismos dibujos con otros colores) y la paleta del sprite (se escribe
  en `V9_PREPARAR_SPRITES.ATRIB`): el rosa es el naranja con la paleta del
  TMS (0-15), que en partida no usa nadie. Así caben en 253 patrones (los
  29 y 30 reflejados, que el juego no usa, ya no tienen los suyos).
  Paleta de sprites: 9 = amarillo de la mascota de Pepsi (el rosa del
  hipopótamo pasa al 15), 12 rojo oscuro, 13 naranja, 14 blanco. Con la
  bola de poder la mascota de Pepsi usa la paleta del TMS, donde el 9 es
  rojo (algo más rojo que el del TMS: 31, 8, 6). Vulnerables y muertos,
  como estaban.

## 11. f2g: primeros reportes del testeo en hardware real (2026-10-22)

- **Redefinir teclas se colgaba (V9990).** `V9_PASO_ESPEJO`, cuando no
  tocaba copiar fila, volvía con HL = `V9_ULTIMO_PASO`. `ESPERAR_TECLA_NUEVA`
  guarda en HL el puntero de `TABLA_TECLAS_MSX` y llama antes a
  `ESPERAR_TECLA_SOLTADA` (que pasa por `V9_PULSACION`): la tecla se
  escribía encima de `V9_ISR` ($6C0B, el `PUSH AF`) y el juego acababa
  reiniciándose. Venía de antes de f2b. Ahora HL se conserva siempre, y la
  espera de tecla nueva (`V9_ESCANEO`, en lugar de `LD DE,$F000`) también
  da pasos del espejo, para que la pantalla de redefinir se vea.
- **Portada nueva de 62 colores (V9990).** `graficos/remake/portada.bmp`
  (la del grafista) se muestra en el modo bitmap B1 (256 × 212, 8 bpp,
  BP6) en vez de la de 16 colores del SCREEN 5. `tools/lz.py` la comprime
  (16 KB) y `V9_DESCOMPRIMIR` (`rom.asm`) la deja al arrancar en la
  dirección `$60000` del modo bitmap, con el V9990 en B1 para que reparta
  los bytes (pares en `$30000`, impares en `$70000` del modo P1, libres) y
  leyendo las copias de la propia VRAM. `v9_portada.asm` ($F010, detrás
  del lienzo del TMS) cambia de modo al entrar y salir de la portada y
  guarda y repone la paleta del juego. Se libera la portada de la capa A.
- **Menú más rápido (V9990).** El espejo convierte por cuartetos con una
  tabla de 16 entradas (`V9_NT`, $7900), las celdas vacías no se
  convierten (`V9_FILA_A_CAPA`: su nombre es el patrón negro), las filas
  pendientes no esperan al frame siguiente y, tras limpiar la pantalla,
  la paleta 0-15 queda en negro hasta que están todas: el menú aparece
  entero de golpe (unos 0,9 s en openMSX, antes lo pintaba fila a fila en
  1,3 s o más).
- Sin GFX9000 la partida es idéntica a f1c (C-BIOS MSX1 y MSX2).

## 12. f2h: segundo testeo en hardware real (2026-10-22)

- **Trampillas (V9990).** Los mapas del grafista no las traen (muro y suelo
  lisos), y solo se veían al moverlas, con la loseta de respaldo.
  `trampillas()` (`tools/graficos.py`) las dibuja sobre las losetas del
  grafista con la forma de las originales (estados A, B y en transición):
  lo que cambia respecto al muro y suelo de al lado va en el color claro
  del muro, en su color principal o en el más oscuro del nivel. Niveles 3,
  4, 8, 10 y 14. Es un apaño hasta que el grafista dibuje las suyas.
- **Excavadora hacia arriba y abajo (V9990).** El grafista solo la dibujó de
  lado y los sprites 14 (abajo) y 15 (arriba) usaban ese dibujo. Ahora el 14
  es el de lado girado un cuarto de vuelta y el 15, el 14 dado la vuelta de
  arriba abajo (`GIROS`). Para que quepan (255 de 256 patrones), el 6 y el
  64 reflejados, que el juego no usa, reutilizan los suyos (`SIN_ESPEJO`).
- **Parpadeo al final de la bola de poder y del hipopótamo (V9990).** En los
  3 últimos segundos (`MODO_ESPECIAL_CUENTA_ATRAS` < 30; el tic va a 10 por
  segundo) se alterna cada medio segundo: el comecocos rojo con sus dibujos
  amarillos (`V9_PARPADEO` en `V9_TIC` y `V9_PAC_AMARILLO` en
  `V9_META_ELEGIR`; la mascota de Pepsi, sin la paleta roja) y el rosa del
  hipopótamo con el amarillo (entrada 15 de los sprites, solo suya).
- **Temblor al coger la bola de poder (máquina real, V9990).** En openMSX
  los dos VDP interrumpen a la par y no se ve. La ISR del TMS tarda hasta
  4 ms con algunos efectos de sonido (la bola de poder) y la tenía las
  interrupciones cerradas; en una máquina real el fin de pantalla del V9990
  llega cuando le toca, y si caía dentro de esa ISR el scroll se escribía
  con la imagen siguiente ya empezada (a 60 Hz el V9990 tiene unos 3 ms sin
  imagen): la pantalla se partía y temblaba mientras sonaba el efecto. Con
  V9990, `V9_ISR` usa `V9_ISR_TMS` (`v9_portada.asm`), la misma ISR con las
  interrupciones abiertas mientras cuenta el frame y suena la música.
- `V9_NT_COLOR` pasa a bucle para dejar sitio en $F010-$F200.
- Sin GFX9000 la partida es idéntica a f1c (C-BIOS MSX1 y MSX2); con GFX9000,
  la partida del nivel 1 es idéntica a f2g.
- **f2i: excavadora de Rubén.** Hacia abajo y hacia arriba son sus dibujos
  (a partir de los originales de MSX1, `graficos/remake/excavadora_vertical.png`,
  `EXCAVADORA`), con brillo y sombra en la pala. Para que quepan, tampoco se
  generan reflejados los sprites de arriba y abajo de la excavadora y del
  hipopótamo (247 patrones de 256).

## 13. f2j (2026-10-23): logo, menú, READY?, dibujos del grafista y R800

- **Logo de Topo atascado (V9990).** Partes del logo (la T, las O) se
  dibujan sin pausas y el espejo del V9990 solo avanzaba en ellas; además
  rehacía tablas a cada cambio de color. Ahora `LOGO_ESPERA` vuelve en
  cuanto llega la interrupción (salta pasos en vez de esperar al V9990),
  `LOGO_VOLCAR_UNA` recorre las filas por turnos, `LOGO_TRAMO` usa tablas
  fijas hechas una vez (`LOGO_M` en $DC00, `LOGO_FONDO`/`LOGO_DIF` en
  $EE00) y `LOGO_WRTVRM_V9` redibuja un poco una vez por interrupción.
  `LOGO_VOLCAR_UNA` no se anida (`.OCUPADO`): el logo también escribe desde
  la interrupción, y anidado se colgaba antes de la portada.
- **«2 JOYSTICK» no se ponía blanco (V9990).** La suma de cada fila del
  espejo (`V9_LEER_FILA`) era Fletcher de 8 bits: cambiar el color de 8·k
  bytes en $60 (de $91 a $F1, 12 caracteres) no la cambiaba. La segunda
  suma gira un bit en cada byte.
- **READY? con fondo negro (V9990).** `V9_COLOR_READY` (`v9_portada.asm`)
  sustituye a `CALL OBTENER_COLOR_VDP` en `MOSTRAR_READY_Y_ARRANCAR_NIVEL`
  y con V9990 deja la tinta y pone el fondo negro. Sin V9990 no cambia.
- **Excavadora arriba/abajo del grafista.** Estaba en la hoja de sprites
  (`or fase 1.png`, 352-383 × 48-63): de espaldas (15) y con la pala
  delante (14). Sustituye a los dibujos de Rubén de f2i.
- **Trampillas del grafista.** Están abajo en la misma hoja (líneas
  224-255): B, en transición y A, uno al lado del otro
  (`TRAMPILLA_DIBUJO`, encajados con las losetas originales). Se pintan
  sobre las losetas del mapa en cada sitio, con los colores más parecidos
  de la paleta del nivel. Sustituye a las sintetizadas de f2h.
- **R800.** En un turbo R (versión 3 en $002D) el arranque llama a CHGCPU
  con $81 (R800 en modo ROM, con el piloto) justo después de medir la
  frecuencia, que cuenta vueltas de un bucle.
- Sin GFX9000 la partida es idéntica a f1c (C-BIOS MSX1 y MSX2). Sin BIOS de
  turbo R aquí, el R800 está sin probar.

## 14. f2k (2026-10-23): bote antes de READY?

- **El laberinto daba un bote al poner READY? (GFX9000; Rubén, Canon V-20).**
  Si la interrupción del V9990 se atiende tarde (con la imagen ya empezada),
  escribir el scroll de la capa B recoloca las líneas que faltan aunque el
  valor sea el mismo: ese frame la ventana salía 7 px más arriba. Pasaba al
  dibujar READY? (en openMSX también se ve, un frame). `V9_FIN_PANTALLA` mira
  el bit VR del estado ($65) y, si ya no está fuera de la imagen, deja el
  scroll para el frame siguiente (los sprites se suben igual).
- En partida (openMSX) no se salta ninguna escritura: 719 de 719 frames.
  Sin GFX9000, idéntica a f1c (C-BIOS MSX1 y MSX2).

## 15. f2l (2026-10-23): logo directo y fantasmas con el hipopótamo

- **Logo de Topo con GFX9000 (Rubén: «sigue yendo fatal»).** Hasta f2k el
  logo apuntaba las celdas cambiadas y las volcaba al V9990 en las esperas;
  en las fases largas con las interrupciones cortadas la imagen se quedaba
  quieta y luego se redibujaba de golpe, de izquierda a derecha. Ahora
  `LOGO_WRTVRM_V9` pinta en el V9990 la línea de la celda en cuanto el logo
  escribe un byte de patrón o de color que cambia: dirección de la celda
  en `LOGO_DIR` ($E800, 2 páginas, la arma `LOGO_COPIAS`) y 4 bytes por la
  máscara del patrón (`LOGO_M`) y los colores (`LOGO_FONDO`). Fuera las
  esperas parcheadas, `LOGO_VOLCAR_UNA` y el volcado al quitar los ganchos.
  En openMSX el V9990 hace la misma animación que el TMS: 6,64 s de logo
  frente a 5,77 s sin GFX9000 (f2k: 6,94 s con parones).
- **Fantasmas azules al pisarlos con el hipopótamo.** Con el hipopótamo el
  juego usa los sprites de fantasma vulnerable (33-36 y el 31/32 reflejado),
  que en el remake son azules. `V9_INDICADORES_ACTOR` da color a los
  fantasmas 27-36 y, con MODO_ESPECIAL 2, cambia los vulnerables por los
  normales (33-36 → 27-30; al 31/32 le quita el reflejo), que salen rojo,
  rosa, cian y naranja. Con la bola de poder siguen azules, como en Pac-Man.
  El color sale ahora de la posición de la entrada (and 3, no su número):
  sigue siendo uno distinto para cada fantasma. Para hacer sitio,
  graficos.py ya no genera las copias de color de 31/32 reflejados, que no
  se leían.
- **R800.** El juego va a 10 tics por segundo fijos (espera la
  interrupción), así que el R800 no lo acelera; solo ayuda en lo que va
  justo de tiempo (logo, menús espejo). Sin BIOS de turbo R aquí, falta que
  Rubén confirme que se enciende el piloto.
- Sin GFX9000 la partida es idéntica a f2k (C-BIOS MSX1 y MSX2), y con
  GFX9000 la salida del TMS también.

## 16. f2m (2026-10-23): flecha contada dos veces y bote tras el logo

- **Fase 2 acabada con una bolita sin comer (Rubén, replay en Canon V-20).**
  Fallo del juego original: el tipo de la loseta que pisa el comecocos se
  guarda en una cache (CACHE_TIPO_LOSETA, por columna). HNDLR_BOLITA_NORMAL
  la pone a 15 al comerse la bolita, pero las 4 flechas no: si el comecocos
  se queda quieto sobre una flecha (empujando contra una pared), el tic
  siguiente la vuelve a leer de la cache y la cuenta otra vez. En el replay
  pasaba en la fase 2 a los 200 s (flecha izquierda, misma posición dos
  tics), y la cuenta llegaba al objetivo con una bolita en el mapa. Las 4
  flechas comparten ahora una cola (HNDLR_AUTOCOCO_COMUN) que deja la
  cache a 15; el bloque ocupa lo mismo que antes (DS de relleno), así que
  no se mueve nada más. Con el arreglo, bolitas que quedan + comidas = 147
  durante todo el replay. También está en la rama msx1 (f0e).
- **Bote al acabar el logo de Topo con GFX9000.** V9_SUBIR volvía a buscar
  el V9990 escribiendo el R#15 (color de fondo) con el logo aún en
  pantalla, y lo reiniciaba (puerto $67) en mitad de la imagen: lo que
  quedaba del frame salía de otro color y desplazado. Ahora se fía de
  LOGO_EN_V9990 (LOGO_GANCHO_QUITAR ya no lo borra) y apaga la pantalla y
  reinicia justo al empezar el borde (VR de 0 a 1). Visto frame a frame a
  50 y 60 Hz: el logo pasa a negro limpio.
- Sin GFX9000 la partida es idéntica a f2l (C-BIOS MSX1 y MSX2), y con
  GFX9000 la salida del TMS también.

## 17. f2n (2026-10-24): la mascota de Pepsi del grafista

- `graficos/remake/pepsi.png`: los 18 dibujos de la mascota redibujados por
  el grafista (24×24, en el orden de PEPSI_IDS; le pasamos los originales
  en `pepsi_grafista/pepsi_sprites.zip`). Amarillo, negro, blanco (ojos) y,
  con la bola de poder (7-11 y 57), rojo. `sprites_pepsi()` los lee de ahí
  (el amarillo a la entrada 9, el resto al color más cercano de la paleta
  de sprites). 252 patrones de 256.
- Con la bola de poder ya no hace falta la paleta del TMS para ponerla
  roja, salvo hacia arriba (6 y 63), que no tiene dibujo rojo:
  `V9_META_ELEGIR` solo cambia la paleta de esos dos.
- Sin GFX9000 la partida es idéntica a f2m, y con GFX9000 la salida del
  TMS también.

## 18. f2o (2026-10-25): las flechas vuelven a obligar a girar

- **Regresión de f2m (Rubén).** Poner CACHE_TIPO_LOSETA a 15 al comer una
  flecha hacía que el tic siguiente despachara HNDLR_SUELO_SIN_BOLA, que con
  TEMPORIZADOR_DIRECCION_FORZADA a 0 borra DIRECCION_FORZADA: ninguna flecha
  obligaba ya a girar. En el original es la cache «atrasada» (sigue diciendo
  flecha) la que mantiene la dirección forzada.
- Ahora la cache no se toca: HNDLR_AUTOCOCO_COMUN fija la dirección siempre
  y, si la loseta ya es la comodín (flecha comida), sale sin volver a
  contarla, dibujarla ni sumar puntos. Con el replay de Rubén la partida va
  igual que con f2l (las flechas mandan) y bolitas que quedan + comidas se
  mantiene (114 en la fase 1, 147 en la 2).
- La partida de compara.sh no pasa por flechas: no detectó la regresión.

## 19. f2p (2026-10-25): suelo bajo las flechas comidas

- **Raya de 1 píxel al comer flechas (nivel 9, Rubén).** El suelo que queda
  al comerse algo (t1, `laberinto()` en graficos.py) era el suelo del mapa
  más parecido al dibujo de la celda. Una flecha tapa la celda entera, así
  que el parecido no dice nada, y salía una variante rara del suelo: la que
  lleva el borde de 1 píxel de un muro a la izquierda.
- Ahora, si el mejor parecido falla en más de la mitad de los píxeles, se
  parte del suelo más frecuente del nivel y se le ponen las 4 columnas de
  la izquierda y las 4 filas de arriba del suelo que lleva el mapa junto
  al mismo muro (si sale al menos 3 veces). Cambian los niveles 1, 3, 9, 11
  y 15 (vistos uno a uno con todo comido); las bolas, igual que antes.

## 20. ROM de pruebas «pasar fase» (2026-10-25)

Pedida por Rubén para el testeo: `python3 tools/build.py --pasarfase`
ensambla con `-DPASAR_FASE` y deja `build/madmix_v9990_pasarfase.rom`.
VERIFICAR_FIN_NIVEL llama a TRUCO_PASAR_FASE (optimizaciones.asm) en
vez de a ACTUALIZAR_LOSETA_BOLA_ESPECIAL (misma longitud: no se mueve
nada del motor, y el truco de vidas sigue en $909A). Si F1 (fila 6,
bit 5) acaba de pulsarse, copia el objetivo del nivel al contador de
cocos comidos y la fase termina por el camino normal; una fase por
pulsación. Sin la opción, la ROM sale idéntica a f2p.

## 21. f2q (2026-10-25): icono de excavadora del nivel 13

El mapa del grafista del nivel 13 trae suelo liso en la celda del icono
de excavadora (valor 62), y no hay otra en ese nivel de la que copiarlo.
graficos.py junta los iconos de transformación (OBJETOS = 61, 62) que
dibujan los mapas de todos los niveles y, si una celda con ese valor sale
como suelo y su nivel no tiene otra dibujada, pone el más frecuente. Los
iconos usan colores fijos de la paleta (7, 13 y 15), así que valen en
cualquier nivel. Solo cambia esa celda.

## 22. f2r (2026-10-25): flecha amarilla del nivel 14

El mapa del grafista del nivel 14 trae amarilla una flecha (fila 6,
columna 31, valor 53). Las flechas (FLECHAS = 52, 53, 54) tapan la
loseta entera, así que graficos.py dibuja todas las de un valor con la
más frecuente de ese valor en su nivel. Es la única que cambia.

## 23. f2s (2026-10-25): segundo icono de excavadora del nivel 14

El nivel 14 tiene dos casillas de excavadora juntas (fila 24, columnas
16 y 17) y el mapa del grafista dibuja mal la segunda. Ahora todas las
casillas de un icono de transformación (OBJETOS) llevan el dibujo más
frecuente de ese valor en todos los mapas, no solo las que salen como
suelo (§21).

## 24. ROM de prueba «volumen» (2026-10-26)

Pedida por Rubén: muñecos con volumen. `python3 tools/build.py --volumen`
(`-DVOLUMEN`, `MADMIX_VOLUMEN=1` para graficos.py) deja
`build/madmix_v9990_volumen.rom`; se combina con `--pasarfase`.

- La paleta de sprites (32-47) está llena, así que los sombreados usan
  la 0-15: en partida no la usa el TMS (la capa A va con la del marco).
  `volumen.asm` (RAM baja, $0040-$00FF) la carga en V9_PONER_MODO al
  entrar en partida y repone la del TMS al volver al espejo.
- graficos.py `sombrear`: altura = distancia al borde de la figura (hasta
  4 px); luz arriba a la izquierda más un degradado en diagonal; tres
  tonos para amarillo, rosa y verde (PALETA_VOLUMEN). Rojo, grises,
  blanco y cian quedan planos (no hay más entradas).
- Fantasmas (27-36) y mascota de Pepsi siguen en la 32-47
  (V9_VOL_ELEGIR). El fantasma rosa usa las entradas 6, 13 y 14 de la
  0-15: en la paleta nueva son la sombra, el cuerpo y el blanco del rosa.
- Con la bola de poder, la mascota de Pepsi hacia arriba sale amarilla
  (su rojo venía de la paleta del TMS).
- La entrada 0 es el color del borde: va en negro.

## 25. f2t (2026-10-26): suelo bajo el Super Coco del nivel 1

Rubén (y el grafista): al comer el Super Coco del nivel 1 quedaba el
suelo con sombra arriba, y la casilla tiene muro a la derecha. Para las
celdas tapadas (bola grande, Super Coco, flechas), graficos.py busca
primero las celdas vacías del nivel con el mismo entorno: muro o hueco
a la izquierda, arriba, derecha y abajo, con la misma loseta de muro.
Vale el entorno que comparte al menos 3 de los 4 lados, y a igualdad el
más frecuente; si no hay, sigue la mezcla de §19. Cambia el suelo de 38
celdas del nivel 1 y de ninguna de las demás fases.

## 26. f2u (2026-10-26): aplastacocos centrado en los pasillos

Rubén: el bicho verde que clava los cocos (Regpunantoso, fases 6 y 7)
iba demasiado a la izquierda al subir y bajar. Los sprites del V9990 se
colocan centrando su caja con la del sprite original, así que el dibujo
seguía fiel al TMS; el desvío viene del motor: los items de
TABLA_ITEMS_* llegan a MOTOR_ACTORES con la columna 2 unidades (4 px)
a la izquierda de la del comecocos en la misma casilla (E=86 frente a
88). Con el dibujo del grafista quedaba montado sobre la pared
izquierda del pasillo.

graficos.py tiene ahora AJUSTE (dx, dy por sprite, sumado al centrado):
+2 px a los sprites 45-53 (los verticales 48-53 y, para que no salte al
girar, también los horizontales 45-47). Comprobado con capturas en el
nivel 6 a la misma posición del actor (X=76) antes y después.

## 27. f2v (2026-10-26): tanque mirando a la izquierda

Rubén: el tanque (sprite 23) mirando a la izquierda iba demasiado a la
derecha. En el original el sprite tiene hueco 0, así que el TMS refleja
la caja entera de 24 px; como el cañón sobresale por la derecha, al
reflejarlo el cuerpo se desplaza 4 px a la derecha. El V9990 copiaba
ese salto. AJUSTE pasa a tener claves (sprite, espejo) y el (23, 1)
lleva -4 px: el cuerpo queda en las mismas columnas (2-17) mirando a
cualquier lado y solo cambia de lado el cañón.
