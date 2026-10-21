# Mad Mix Game v9990 — resumen del proyecto

*Estado a 20 de octubre de 2026 (F1 terminada).*

## Objetivo

Versión mejorada de *Mad Mix Game* (Topo Soft, 1988) para **MSX1 con
64 KB de RAM**, distribuida como **megaROM ASCII16**. Tiene dos metas:

1. Un juego base optimizado para MSX1 con el VDP original (TMS9918).
   **Hecho.**
2. Un port del gráfico al **V9990 (cartucho GFX9000)**, usando su scroll
   y sus sprites por hardware. **F1 hecha (laberinto y scroll); sigue F2
   (actores como sprites).**

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
| `$6C00-$6F90` | código del V9990 (`v9990.asm`, F1) |
| `$7C50-$7FEF` | sombra de la matriz del nivel (F1, no se carga) |
| resto hasta `$83FF` | libre para F2-F4 |
| `$8400-$DDA0` | motor (`MADMIX1.BIN`) |
| `$DE04-$EFFF` | `BUFFER_LOSETAS_TRABAJO`, el bitmap del laberinto |
| `$F2FF` hacia abajo | pila |
| `$FC50-$FFEF` | matriz del nivel activo |

Controles: cursores y espacio por defecto desde f0d/f1b (el original usaba Q/A/O/P); pausa en la fila 3, bit 5. Están en `TABLA_TECLAS_MSX`, que es la misma tabla que rellena la opción de redefinir teclas.

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
| `f0d` (ROM, sin etiqueta) | f0c con cursores y espacio por defecto. Igual que `f1b`, que es F1 con el mismo cambio |
| `f0e` (rama `msx1`) | f0d con el volcado sincronizado con el haz (`volcado_haz.asm`): sin cortes al hacer scroll. Igual que `f1c` en `master` |

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

## F1 hecha: laberinto en el V9990

Detalle completo en `DISENO.md` §6 del repositorio.

- `V9_INICIAR` ($6C00), llamado por el cargador: detecta el GFX9000
  (R#15 de lectura y escritura), modo P1, paleta del TMS, convierte las
  91 losetas a 4 bpp en el generador de la capa B y pone en la capa A
  una máscara negra fuera de la ventana de 24×18 caracteres en (32,24).
- La matriz entera va a la capa B ($7E000, loseta (r,c) en
  $7E000 + r·256 + c·4). Una sombra de la matriz decide qué losetas
  reescribir: zona visible y una fila en rotación en cada tic, matriz
  entera al cargar nivel (parche en `CARGAR_NIVEL`).
- Scroll de la capa B = (L·4 − 32, H·4 − 24) con (L,H) la cámara
  ($2C02), escrito en la interrupción de fin de pantalla del V9990
  (`V9_ISR` delante de la ISR del juego). Escribirlo con la imagen en
  curso parte la pantalla.
- Colores: entradas 17/18 de la paleta con el color que el juego pinta
  en la ventana del TMS (tabla clásica del TMS9918).
- Verificado en openMSX (C-BIOS 50 y 60 Hz): sin GFX9000 la demo
  determinista es idéntica a f0c tic a tic; con GFX9000 el estado del
  juego también; la ventana del V9990 coincide con la del TMS salvo los
  actores y el texto "READY?".
- Coste: `V9_TIC` ~0,19 frames por tic. La demo va un 3 % más lenta
  que f0c porque el TMS sigue dibujando todo; F2 lo compensa.
- Con GFX9000 los menús y la portada se siguen viendo solo en el TMS;
  el V9990 queda en negro hasta el primer nivel y después muestra el
  último laberinto (F4).

## Plan del port al V9990

| Fase | Contenido |
|---|---|
| F1 | **Hecha.** Detectar e iniciar el V9990 en modo P1 (256×212); paleta; convertir las 91 losetas a 4 bpp; laberinto entero en la capa B (512×512 px) con scroll por hardware ligado a la cámara |
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

- **Repositorio git completo** (historia y etiquetas `f0`, `f0b`, `f0c`,
  `f1`, `f1c`; `f0e` en la rama `msx1`): `/mnt/project-files/mad_mix_v9990/mad_mix_v9990_repo.zip`.
  Aún no está en GitHub.
- Estructura: `src/juego/` (fuentes del juego con los parches,
  `optimizaciones.asm` y `v9990.asm`), `src/rom/rom.asm` (cargador),
  `tools/build.py`, `pruebas/`, `DISENO.md`, `ANALISIS_RENDIMIENTO.md`.
- ROM: `madmix_roms.zip` (f0 a f0e, F1 a f1c) y `madmix_v9990_f1_rom.zip` (solo F1,
  ASCII16 128 KB). Sin GFX9000 funciona igual que f0c. Desde el 2026-10-20 llevan 4 `LD ($77FF),A` como datos al final del banco 0 para que openMSX detecte ASCII16 solo (antes elegía Konami).
- Comparativa TMS/V9990 en openMSX: `comparativa_f1.png`.
- Entorno de pruebas en la nube: sjasmplus 1.24 compilado sin Lua
  (`make USE_LUA=0`), openMSX 20 compilado e instalado en
  `/opt/openMSX`, C-BIOS 0.29a de SourceForge. `pruebas/msxshot.sh` ya
  no lleva rutas fijas; `MSX_SIN_GFX9000=1` quita el cartucho.
- **Falta probar en máquina real**: f0c y F1 (openMSX con ROM de
  sistema real, la HB-F900 o hardware, con y sin GFX9000).

## Créditos

- Juego original: Topo Soft. Programación "Raphael Gomezzz", gráficos
  Roberto P. Acebes, música "Comilonas".
- Desensamblado y documentación de la base: Rafael Eduardo Martín
  Candial.
- Arreglo del nivel 13/14 y pila en `$F2FF`: Manuel Pazos (2013).

## Fallo gráfico al hacer scroll (resuelto en f0e/f1c, 2026-10-21)
Rubén veía trozos de pared desplazados al hacer scroll (f0c/f0d, openMSX y HB-20P). Con su replay de openMSX (MadMixGame.omr, HB-20P) se vio la causa: el buffer siempre está bien, pero volcarlo al TMS9918 cuesta ~1,5 frames y el haz alcanzaba la fila que se estaba escribiendo (una fila a medio escribir por tic). También pasa en el juego original.
- Arreglo (`src/juego/volcado_haz.asm`): cada fila se escribe detrás del haz. Referencia de línea: 5 sprites transparentes en Y=24 y el indicador de quinto sprite. Las filas 7-11 (5 a 50 Hz, 2 a 60 Hz) se trasponen antes y se envían con OUTI en el borde; si solo caben 4, la siguiente va a 26 ciclos por byte, aún en el borde; si caben menos, se vuelca un frame después. La música de la ISR se aplaza al final del volcado.
- Medido en openMSX 21 a 50 Hz: la fila 17 acaba hacia la línea 521-531 con el límite en la 534; ningún fotograma cortado en 500 capturas de partida (f0d: un corte por tic). A 60 Hz no cabe: las 4 últimas filas se ven un frame tarde (f0d tenía dos cortes por tic).
- La demo determinista da el mismo estado y el mismo buffer tic a tic que f0d/f1b. Coste: ~3-4 % menos de tics por segundo en la demo (9,35 → 9,06 en f0e a 50 Hz), porque el volcado espera a que el haz pase la fila 0.
- Las filas traspuestas van en $7FF0-$83B0 (libre tras SOMBRA_MATRIZ). Falta que Rubén lo pruebe en la HB-20P y la HB-F900.
- Para reproducir un replay de una máquina real sin su BIOS: openMSX 21 compilado (/opt/openMSX21) y cambiar en el .omr el sha1 de la BIOS por el de la C-BIOS equivalente.
