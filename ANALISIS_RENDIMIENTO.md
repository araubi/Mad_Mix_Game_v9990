# Rendimiento del juego base (MSX1, TMS9918) — medición

Medido en openMSX (C-BIOS MSX1 a 60 Hz y C-BIOS MSX1 EU a 50 Hz) sobre
la ROM F0, que es el juego original con los arreglos de Pazos. Se
jugaron 30 s seguidos, moviendo al comecocos en círculo. Durante ese
tiempo se muestreó el PC cada 0,25 ms y se tomaron marcas de tiempo en
el bucle principal, la interrupción y el volcado a VRAM. Herramientas:
`pruebas/perfil.tcl` y `pruebas/analiza_perfil.py`.

## Resultados

| | 60 Hz | 50 Hz |
|---|---|---|
| Tics de juego por segundo | 9,3 | 9,6 |
| Frames por tic (reparto) | 4–10, media 5,7 | 3–7, media 5,2 |
| Interrupciones perdidas | 35 % | 38 % |
| `ACTUALIZAR_VRAM_FRAME` por tic | 163 000 ciclos (2,7 frames) | 156 000 ciclos (2,2 frames) |
| — volcado de 3456 bytes | 126 000 ciclos (36 ciclos/byte) | igual |
| — relleno `LDIR` de 1323 bytes / icono del HUD | 37 000 ciclos de media | 31 000 |
| CPU en `ACTUALIZAR_VRAM_FRAME` | 42 % | 41 % |
| CPU en scroll (`SCROLL_*`, `APLICAR_DESPLAZAMIENTO_LATERAL`) | ~14 % | ~21 % |
| CPU en actores (`MOTOR_ACTORES` y compañía) | ~10 % | ~10 % |
| CPU esperando (`WAIT_VBLANK`) | 8 % | 9 % |

## Diagnóstico

1. **El juego va limitado por la CPU, no por un ritmo fijo.** Cada tic
   dura lo que tarde el trabajo de ese tic: de 3 a 10 frames. Por eso el
   movimiento da tirones y la velocidad varía según lo que haya en
   pantalla.
2. **Todo el volcado a VRAM se hace dentro de la interrupción y con las
   interrupciones cerradas.** `GESTIONAR_FRAME` llama a
   `ACTUALIZAR_VRAM_FRAME` desde la ISR, y esa rutina dura más de 2
   frames. Durante ese tiempo se pierden las interrupciones de VBLANK:
   más de un tercio del total. Como el driver de sonido
   (`DESPACHAR_EFECTO_SONIDO`) también se ejecuta en la ISR, **la
   música y los efectos van más o menos un 35 % más lentos durante la
   partida y con tempo irregular.**
3. **El relleno `LDIR $4000→$4000` de 1323 bytes es tiempo perdido a
   propósito** (~28 000 ciclos, medio frame por tic). Se ejecuta en cada
   tic en el que no cambia el icono del HUD. Probablemente intenta
   igualar la duración con el caso en que sí cambia, pero el resultado no
   cuadra (la base ya lo marcaba como misterio).
4. **El volcado (36 ciclos por byte) está cerca del límite del TMS9918**
   en pantalla activa (unos 29 ciclos entre escrituras). Afinándolo se
   gana como mucho un 20 %. Rehacer el render en modo carácter, con
   losetas precalculadas, reduciría el tráfico 8 veces, pero es una
   reescritura completa del motor gráfico del TMS.

## Propuesta para el juego base

Por orden de beneficio y riesgo:

1. **Sacar el volcado de la ISR.** El bucle principal lo hace tras
   `WAIT_VBLANK` con las interrupciones abiertas. Mientras se escribe
   VRAM, la ISR no toca el VDP: el registro 1 queda pendiente para la
   siguiente interrupción, porque escribir un registro del TMS altera el
   puntero de VRAM. Resultado: 0 % de interrupciones perdidas, música a
   su tempo y lectura de controles regular.
2. **Tic a ritmo fijo**: 5 frames a 50 Hz y 6 a 60 Hz, es decir, 10 tics
   por segundo en ambas máquinas. Es la media actual (9,3–9,6), así que
   la jugabilidad no cambia, pero desaparecen los tirones y la velocidad
   es la misma en máquinas europeas y japonesas.
3. **Quitar el relleno `LDIR`** y ajustar el volcado al límite del TMS,
   para tener margen y que ningún tic se pase de su presupuesto de
   frames.

Más tics por segundo de serie haría el juego más rápido de lo que se
diseñó (el comecocos avanza 4 px por tic). Un movimiento más fino, de
2 px a 20 tics/s, es posible pero toca la lógica de colisión. Queda como
mejora opcional.

## Relación con el port al V9990

En el V9990 desaparecen el volcado, el scroll por software y el dibujado
de actores: más o menos el 70 % de la CPU actual. Los puntos 1 y 2 valen
igual para esa versión, porque la ISR no debe tardar más de un frame y
el tic tiene que ser fijo.

## Resultado de la versión optimizada

Aplicadas las tres mejoras en `src/juego/optimizaciones.asm` (código
nuevo en `$6500-$6971`) más 4 parches del mismo tamaño en el motor, de
modo que ninguna etiqueta del original cambia de dirección. El
cargador mide la frecuencia (no se fía de `$002B`) y fija 5 frames por
tic a 50 Hz y 6 a 60 Hz.

| | Original 60 Hz | Optimizada 60 Hz | Original 50 Hz | Optimizada 50 Hz |
|---|---|---|---|---|
| Interrupciones perdidas | 35 % | **0 %** | 38 % | **0 %** |
| Frames por tic | 4–10 | **6 en el 88 %**, 7–8 resto | 3–7 | **5 en el 90 %**, 6–7 resto |
| `ACTUALIZAR_VRAM_FRAME` | 163 000 ciclos | 124 000 (incluye la ISR que ahora entra entre filas) | 156 000 | 125 000 |
| Accesos a VRAM demasiado rápidos (openMSX, modo `real`) | — | 0 | — | 0 |

Las dos máquinas juegan igual: a los mismos segundos de partida el
comecocos está en la misma posición y con la misma puntuación.

**Pendiente (opcional):** alrededor del 10 % de los tics se pasan un
frame. Son los que combinan scroll y volcado completo. El scroll ya
está desenrollado (`RLD`/`LDI`); bajar de ahí exigiría convertir
`BUFFER_LOSETAS_TRABAJO` en un buffer circular para no copiarlo en cada
paso. Ese cambio toca el volcado y el dibujado de actores.

## Segunda ronda: el ~10 % de tics que se pasan

### Método

Una partida jugada no sirve para comparar versiones. Las teclas van por
tiempo y `GENERAR_ALEATORIO` usa el registro `R`, cuyo valor depende de
cuántas instrucciones se hayan ejecutado. Por eso cada versión juega
una partida distinta. Se ha añadido una compilación de pruebas
(`tools/build.py --pruebas`) que cambia `LD A,R` por `LD A,L`, de modo
que la demo, que lleva la entrada grabada, es idéntica tic a tic en
cualquier versión. Con `PERF_HASH=1`, `pruebas/perfil.tcl` saca en cada
tic una huella de:
- las variables (`$2B00-$2DFF`),
- la matriz del nivel,
- la parte visible de `BUFFER_LOSETAS_TRABAJO`.

`pruebas/compara_estado.py` compara esas huellas. Desglose por tic:
`analiza_tics.py`, `analiza_carga.py` y `ritmo.py`.

### Qué hace que un tic se pase

Tics que se pasan frente a tics a tiempo, en frames por tic (demo a
50 Hz):

| | se pasan | a tiempo |
|---|---|---|
| Volcado a VRAM | 1,57 | 1,53 |
| Scroll horizontal (`RLD` en 144 × 24 bytes) | 1,07 | 0,84 |
| Actores | **1,74** | 0,48 |
| — de ellos `DIBUJAR_FILA_DESPLAZADA_DERECHA` | 0,81 | 0,10 |

Desplazamientos sub-píxel medidos: solo 0, 2, 4 y 6 (los actores se
mueven de 2 en 2 px). El de 6 a la derecha costaba 6 pasos de unos 89
ciclos por fila.

### Cambios

1. `INVERTIR_BITS_OPT`: el espejo de los patrones se hace con una tabla
   de 256 bytes. Comprobado en 26 llamadas reales que el resultado
   coincide byte a byte con el original.
2. `DIBUJAR_FILA_DESPLAZADA_6`: el desplazamiento de 6 a la derecha se
   hace como 2 pasos a la izquierda, con un registro que recoge lo que
   sale por arriba.
3. `ESPERAR_TIC` con recuperación: si un tic llega un frame tarde, el
   siguiente se adelanta ese frame. Si el retraso es mayor, se
   resincroniza. Se aplica también a la demo, que antes iba sin ritmo
   fijo.

**Verificación:** en 370 tics de la demo determinista, el estado del
juego y cada píxel visible del buffer son idénticos a los de `f0b` (y
a los del original, `f0`). En todas las pasadas hubo 0 accesos a VRAM
demasiado rápidos y 0 escrituras en `$6C00-$83FF`.

### Resultado

Carga por tic sobre los mismos 364 tics de la demo:

| | carga media | p90 | p99 | tics que no caben |
|---|---|---|---|---|
| f0b, 50 Hz | 4,68 | 5,89 | 6,73 | 38 % |
| ahora, 50 Hz | 4,63 | 5,71 | 6,33 | 36 % |
| f0b, 60 Hz | 5,69 | 7,31 | 8,20 | 41 % |
| ahora, 60 Hz | 5,64 | 6,98 | 7,64 | 41 % |

Los tics más pesados bajan un 6-7 % y en la demo a 50 Hz los tics de 7
frames pasan de 24 a 8. La demo es el peor caso, porque hace scroll en
casi todos los tics. En partida los tics pesados vienen sueltos, y ahí
la recuperación de un frame evita que el juego pierda velocidad.

**Límite del TMS9918.** Un tic con scroll horizontal y varios
fantasmas necesita unos 1,4 frames de volcado (a la velocidad máxima
del VDP), alrededor de 1 frame de scroll y de 1 a 1,7 frames de
actores. Con 5 frames de presupuesto a 50 Hz eso no siempre cabe.
Bajar de ahí obliga a reescribir el render del TMS en modo carácter, con
losetas precalculadas en lugar de un mapa de bits. Es justo lo que
resuelve el port al V9990 (scroll y sprites por hardware), así que se
deja aquí la versión MSX1.
