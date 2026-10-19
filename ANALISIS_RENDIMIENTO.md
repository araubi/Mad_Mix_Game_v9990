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
