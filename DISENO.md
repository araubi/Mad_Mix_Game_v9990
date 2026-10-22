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
