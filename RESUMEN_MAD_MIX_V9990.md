# Mad Mix Game v9990 — resumen del proyecto

*Estado a 20 de octubre de 2026.*

## Objetivo

Versión mejorada de *Mad Mix Game* (Topo Soft, 1988) para **MSX1 con
64 KB de RAM**, distribuida como **megaROM ASCII16**. Tiene dos metas:

1. Un juego base optimizado para MSX1 con el VDP original (TMS9918).
   **Hecho.**
2. Un port del gráfico al **V9990 (cartucho GFX9000)**, usando su scroll
   y sus sprites por hardware. **Pendiente: fase F1.**

## Material de partida

- **Desensamblado completo** de Rafael Eduardo Martín Candial:
  [github.com/raemca/MSX_MadMixGame](https://github.com/raemca/MSX_MadMixGame),
  commit `a90cf51`, licencia CC BY-NC-SA 4.0. Se ensambla con
  SjASMPlus y reproduce el original byte a byte. Trae manuales del
  motor gráfico, de colisión e IA, de los niveles y del sonido.
- **Dos CAS** del usuario: el original de 1988, con bug, y la versión
  arreglada por **Manuel Pazos (2013)**.
- **Diferencias del CAS de Pazos frente al original**, obtenidas
  comparando bloque a bloque:
  - las 5 constantes `$FC60` pasan a `$FC50`: arregla el contador de
    bolitas del nivel 13, que no dejaba pasar al 14. El repositorio de
    raemca ya lo aplica;
  - la pila pasa a `$F2FF` en `INICIO` (`$8F26`); el original la tenía
    en `$0FFF`;
  - una línea `REM` de créditos en el cargador BASIC.
  
  El bloque de 180 bytes en `$C9BC` que el repositorio atribuía a la
  v2.0 no está en este CAS.

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Alcance V9990 | Reescritura del gráfico (scroll y sprites por hardware), no un volcado del render actual |
| Máquina | MSX1, 64 KB de RAM |
| Formato | megaROM ASCII16 |
| Pila | `$F2FF`, como en la versión de Pazos |
| Primero | Optimizar el juego base antes de empezar con el V9990 |
| Licencia del proyecto | CC BY-NC-SA 4.0, porque deriva del desensamblado |

## Arquitectura de la ROM

- **Banco 0**: cabecera `AB` y cargador. **Bancos 1 a n**: imagen RAM del
  juego y logo de Topo, troceados en fragmentos de hasta 2 KB.
- El cargador:
  - detecta el slot del cartucho y el de la RAM de la página 3, y
    comprueba que haya RAM en las páginas 0-2;
  - reproduce `COLOR 1,1,1:SCREEN 2` y muestra el logo de Topo con la
    BIOS;
  - mide si la máquina va a 50 o 60 Hz contando vueltas de un bucle
    durante 4 interrupciones, sin fiarse de `$002B`;
  - copia el juego a sus direcciones originales (`$1000-$64FF`,
    `$6500-$6BFF` código nuevo, `$8400-$DDA0`), deja las 4 páginas en
    RAM y salta a `$8400`.
- **Lección aprendida**: no escribir en `$4000-$7FFF` con la ROM visible,
  porque la escritura acaba en un registro del mapper ASCII16 y no en la
  RAM. Pasó con `TIC_FRAMES`, en `$6500`.

## Mapa de RAM del juego

| Zona | Uso |
|---|---|
| `$0000-$0FFF` | RAM baja: ISR en `$0038` y cursor de máscaras de actores en `$0500` |
| `$1000-$64FF` | `MADMIX.SCR`: portada, colisión, ítems, niveles y menú |
| `$6500-$6BFF` | **código nuevo** (`optimizaciones.asm`) |
| `$6C00-$83FF` | libre (~6 KB), reservado para el código del V9990 |
| `$8400-$DDA0` | motor (`MADMIX1.BIN`) |
| `$DE04-$EFFF` | `BUFFER_LOSETAS_TRABAJO`, el bitmap del laberinto |
| `$F2FF` hacia abajo | pila |
| `$FC50-$FFEF` | matriz del nivel activo |

Controles: Q/A/O/P y espacio; pausa en la fila 3, bit 5.

## Rendimiento: diagnóstico del original

Medido en openMSX con muestreo del PC cada 0,25 ms durante la partida:

- **Sin ritmo fijo**: cada tic dura de 3 a 10 frames según la carga.
  El resultado son tirones y una velocidad distinta según la máquina.
- **El volcado de 3456 bytes a VRAM se hace dentro de la ISR, con DI**,
  y dura más de 2 frames. Se pierde el **35-38 % de las
  interrupciones**, así que la música suena más lenta e irregular.
- Hay un `LDIR $4000→$4000` de 1323 bytes que no hace nada, en cada tic.
- El reparto de la CPU: volcado 42 %, scroll 14-21 %, actores 10 %.

## Versiones optimizadas (MSX1, TMS9918)

| Etiqueta | Cambios |
|---|---|
| `f0` | Juego original con el cargador ROM y los arreglos de Pazos (referencia) |
| `f0b` | Volcado fuera de la ISR, que solo cuenta frames y hace sonar el PSG; tic fijo de 5 frames a 50 Hz y 6 a 60 Hz; sin el `LDIR`; volcado desenrollado a 30 ciclos por byte |
| `f0c` | Espejo de actores con tabla de 256 bytes; desplazamiento sub-píxel de 6 hecho como 2 pasos; paso fijo con recuperación de un frame; la demo usa el mismo ritmo |

Todo el código nuevo está en `optimizaciones.asm`. El motor original
solo lleva 6 parches del mismo tamaño, así que **ninguna etiqueta del
original cambia de dirección**.

**Resultados:**

| | Original | f0c |
|---|---|---|
| Interrupciones perdidas | 35-38 % | **0 %** |
| Tics por segundo | 9,3-9,6, irregular | ~10, regular, igual a 50 y 60 Hz |
| Carga p99 por tic (demo a 50 Hz) | 7,32 frames | 6,33 frames |
| Accesos a VRAM demasiado rápidos | — | 0 |

**Límite del TMS9918.** Los tics con scroll horizontal y varios
fantasmas siguen pasándose de presupuesto:
- volcado: ~1,4 frames, ya a la velocidad máxima del VDP;
- scroll: ~1 frame;
- actores: 1-1,7 frames.

Bajar de ahí obligaría a rehacer el render del TMS en modo carácter.
Se deja así, porque el V9990 lo resuelve.

## Método de verificación (reutilizable en otros proyectos)

- **openMSX sin pantalla** en el entorno de trabajo:
  - compilado con SDL2, Tcl y GLEW;
  - capturas con `screenshot -raw` bajo Xvfb;
  - `-ext gfx9000`, y `set videosource GFX9000` para capturar la salida
    del V9990;
  - con `throttle off` las capturas salen negras: hay que activar el
    throttle un momento antes de capturar.
- Máquinas de prueba: `C-BIOS_MSX1` (60 Hz) y `C-BIOS_MSX1_EU` (50 Hz).
- `too_fast_vram_access real` junto con su callback detecta accesos a
  VRAM más rápidos de lo que admite el hardware real.
- **Comparar versiones sin falsos positivos**:
  - El juego saca su azar de `LD A,R`, así que cada versión juega una
    partida distinta.
  - La compilación de pruebas (`build.py --pruebas`) cambia esa
    instrucción por `LD A,L`.
  - Con ese cambio, la demo (entrada grabada) es idéntica tic a tic.
  - En cada tic se guarda una huella CRC de las variables, la matriz del
    nivel y la parte visible del buffer.
  - Las huellas de dos versiones se comparan una a una.
- Herramientas en `pruebas/`:
  - `msxshot.sh`: arranca una ROM y saca capturas;
  - `perfil.tcl` y `perfil.sh`: muestreo del PC, marcas de tiempo y
    huellas por tic;
  - `analiza_perfil.py`, `analiza_tics.py`, `analiza_carga.py`,
    `ritmo.py` y `compara_estado.py`: análisis de las mediciones.

## Plan del port al V9990 (pendiente)

| Fase | Contenido |
|---|---|
| F1 | Detectar e iniciar el V9990 en modo P1 (256×212); paleta; convertir las 91 losetas a 4 bpp; laberinto entero en la capa B (512×512 px) con scroll por hardware ligado a la cámara |
| F2 | Actores como sprites hardware de 16×16 (más versiones espejadas); retirar `MOTOR_ACTORES` y el volcado |
| F3 | Capa A: marco de caramelo, marcador, vidas, icono y destellos del HUD |
| F4 | Portada, menú, créditos, presentación de nivel y Game Over |
| F5 | Limpiar el código del TMS y mejoras opcionales: ventana más grande, colores nuevos |

**Datos del V9990 en modo P1**, comprobados en el código de openMSX:
- tabla de nombres de la capa A en `$7C000` y de la capa B en `$7E000`;
- atributos de sprites en `$3FE00`;
- 125 sprites, 16 por línea;
- un sprite con prioridad "detrás" queda bajo la capa A, así que el
  marco recortará los actores en el borde de la ventana sin hacer nada
  más.

**Pregunta abierta**: en el V9990, ¿reproducir primero los colores del
original o rediseñarlos? Propuesta: reproducirlos primero.

## Dónde está el código

- Repositorio git local en el espacio de trabajo de la conversación,
  con 5 commits y las etiquetas `f0`, `f0b` y `f0c`. **Aún no está
  publicado**: falta crear un repositorio en GitHub y dar acceso, o
  copiarlo a una carpeta del PC.
- Estructura: `src/juego/` (fuentes del juego con los parches),
  `src/rom/rom.asm` (cargador), `tools/build.py`, `pruebas/`,
  `DISENO.md`, `ANALISIS_RENDIMIENTO.md`.
- ROM entregada: `madmix_msx1_optimizada_f0c.rom`. Probada en openMSX
  con C-BIOS; **falta probarla en una máquina real** (tu openMSX con la
  ROM del sistema, la HB-F900 o hardware).

## Créditos

- Juego original: Topo Soft. Programación "Raphael Gomezzz", gráficos
  Roberto P. Acebes, música "Comilonas".
- Desensamblado y documentación de la base: Rafael Eduardo Martín
  Candial.
- Arreglo del nivel 13/14 y pila en `$F2FF`: Manuel Pazos (2013).
