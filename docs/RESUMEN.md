# Mad Mix Game v9990 — resumen del proyecto

*Diario del proyecto tal como se fue escribiendo. Los `madmix_fXX.zip` que se
citan son las entregas de cada versión; cada una tiene su etiqueta en este
repositorio (`f2b` ... `f34`) y se reconstruye con `tools/build.py`.*

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

## F2 hecha: versión completa en el V9990 (2026-10-21)
ROM `madmix_v9990_f2.rom` (256 KB ASCII16, openMSX la detecta sola), en
`madmix_f2.zip`; repo con tag `f2`. Con GFX9000: laberinto con las losetas
y paletas del grafista en las 15 fases, actores como sprites, marco,
marcador y portada nuevos, textos FASE/READY?/ESTÁS FRITO, y menús copiados
de la pantalla del TMS. Sin GFX9000: idéntica a f1c. Probada en openMSX
(C-BIOS MSX1 y MSX2) hasta el fin de partida; falta máquina real y que
araubi la vea. Diseño en DISENO.md §7.

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
  `f1`, `f1c`; `f0e` en la rama `msx1`): este repositorio.
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
araubi veía trozos de pared desplazados al hacer scroll (f0c/f0d, openMSX y HB-20P). Con su replay de openMSX (MadMixGame.omr, HB-20P) se vio la causa: el buffer siempre está bien, pero volcarlo al TMS9918 cuesta ~1,5 frames y el haz alcanzaba la fila que se estaba escribiendo (una fila a medio escribir por tic). También pasa en el juego original.
- Arreglo (`src/juego/volcado_haz.asm`): cada fila se escribe detrás del haz. Referencia de línea: 5 sprites transparentes en Y=24 y el indicador de quinto sprite. Las filas 7-11 (5 a 50 Hz, 2 a 60 Hz) se trasponen antes y se envían con OUTI en el borde; si solo caben 4, la siguiente va a 26 ciclos por byte, aún en el borde; si caben menos, se vuelca un frame después. La música de la ISR se aplaza al final del volcado.
- Medido en openMSX 21 a 50 Hz: la fila 17 acaba hacia la línea 521-531 con el límite en la 534; ningún fotograma cortado en 500 capturas de partida (f0d: un corte por tic). A 60 Hz no cabe: las 4 últimas filas se ven un frame tarde (f0d tenía dos cortes por tic).
- La demo determinista da el mismo estado y el mismo buffer tic a tic que f0d/f1b. Coste: ~3-4 % menos de tics por segundo en la demo (9,35 → 9,06 en f0e a 50 Hz), porque el volcado espera a que el haz pase la fila 0.
- Las filas traspuestas van en $7FF0-$83B0 (libre tras SOMBRA_MATRIZ). Falta que araubi lo pruebe en la HB-20P y la HB-F900.
- Para reproducir un replay de una máquina real sin su BIOS: openMSX 21 compilado (/opt/openMSX21) y cambiar en el .omr el sha1 de la BIOS por el de la C-BIOS equivalente.

## f2b (2026-10-22): fantasmas, logo de Topo en la GFX9000 y pantalla de carga fija
- ROM: `madmix_f2b.zip` (madmix_v9990_f2b.rom + capturas). Repo con la etiqueta `f2b` en `mad_mix_v9990_repo.zip`; detalles en DISENO.md §8.
- Los fantasmas ya miran hacia donde van (estaban cambiados el dibujo normal y el girado).
- El logo de Topo Soft sale entero en la GFX9000 y sincronizado con el del TMS. Al principio va algo más lento: en openMSX con C-BIOS MSX2 tarda 7,65 s frente a 6,03 s.
- Con GFX9000, la pantalla del MSX muestra la pantalla de carga original:
  - En MSX2 se queda todo el rato, porque se guarda en la VRAM alta del V9938.
  - En MSX1 solo se ve al arrancar y durante el logo, porque el juego necesita los 16 KB del TMS y la pinta encima.
- Sin GFX9000, el juego es idéntico a f1c en C-BIOS MSX1 y MSX2.
- Diferencias con The Pepsi Challenge, la versión inglesa: [PEPSI_DIFERENCIAS.md](PEPSI_DIFERENCIAS.md).

## f2c (2026-10-22): opción 3, Mad Mix Game o The Pepsi Challenge
- ROM: `madmix_f2c.zip`. Detalles en DISENO.md §9 y `src/juego/pepsi.asm`.
- Menú nuevo:
  - 1 TECLADO
  - 2 JOYSTICK
  - 3 MAD MIX GAME / THE PEPSI CHALLENGE (la tecla 3 alterna)
  - 4 REDEFINE TECLAS
  - 5 DEMO
  - 0 JUGAR
- The Pepsi Challenge:
  - La mascota de Pepsi sale en lugar del comecocos, también en la GFX9000, donde va en amarillo.
  - Empieza en el nivel 2, que se ve como fase 1, y vuelve al 2 después del 15, que se ve como 14.
- Sin cambiar de juego, la partida es idéntica a f1c.
- La ROM sigue en 256 KB porque la carga empieza en el banco 0.

## f2d (2026-10-22): arreglos a f2c
- ROM: `madmix_f2d.zip` (madmix_v9990_f2d.rom + capturas). Detalles en DISENO.md §10 (ahora también §8 y §9).
- GFX9000: el comecocos mirando a la izquierda iba 6 píxeles a la derecha (no llegaba al borde y comía antes de tiempo). Ya va donde lo pone el TMS.
- The Pepsi Challenge con la animación de su cinta: sube andando (Mad Mix usa un dibujo quieto) y con la bola de poder baja en su orden. En TMS y GFX9000.
- GFX9000: con la bola de poder el comecocos también es rojo hacia arriba (dibujo del grafista).
- Nivel 1: se ven los tres cocos junto a la salida, que el mapa del grafista no traía; también algún objeto suelto en los niveles 6, 8, 11 y 15.
- Sin cambiar de juego, idéntica a f1c en el TMS (C-BIOS MSX1 y MSX2). Falta que araubi la pruebe.

## f2e (2026-10-22): fantasmas blancos hacia arriba
- ROM: `madmix_f2e.zip`. GFX9000: tras el super coco los fantasmas que suben ya salen blancos (el juego usaba para subir el mismo sprite que los normales). DISENO.md §10. TMS sin cambios (idéntica a f1c).

## f2f (2026-10-22): fantasmas de colores y Pepsi roja
- ROM: `madmix_f2f.zip`. GFX9000: fantasmas rojo, rosa, cian y naranja como en Pac-Man (vulnerables y muertos como antes); la mascota de Pepsi se pone roja con el supercoco. DISENO.md §10. TMS sin cambios (idéntica a f1c). araubi va a hacer un testeo a fondo.


## f2g (2026-10-22): primeros reportes del testeo

Entregado en `madmix_f2g.zip` (`madmix_v9990_f2g.rom` + capturas).

- Redefinir teclas ya no se cuelga con GFX9000 (la tecla se escribía encima de la rutina de interrupción del V9990; venía de f2b).
- Portada nueva del grafista (`portada.bmp`, 62 colores) en el V9990, en modo bitmap; con ella se va el gris lila.
- El menú aparece entero de golpe y antes (~0,9 s en openMSX).
- Pendiente: el temblor al transformarse junto a la frontera eléctrica (no reproducido aún).

## f2h (2026-10-22): madmix_f2h.zip

Segundo testeo de araubi en máquina real.
- Trampillas visibles desde el principio (el mapa del grafista no las traía; dibujadas con la forma de las originales en los colores del nivel). Mejor si el grafista dibuja las suyas.
- Excavadora con dibujo hacia arriba y hacia abajo (el de lado girado; el grafista solo dibujó el de lado).
- Últimos 3 s de la bola de poder: el comecocos alterna rojo y amarillo cada 0,5 s; del hipopótamo, rosa y amarillo.
- Temblor al coger la bola de poder: causa probable, la ISR del TMS (hasta 4 ms con ese efecto) retrasaba el scroll del V9990 en máquina real; ahora deja interrumpir al V9990. No se ve en openMSX (los dos VDP van a la par): falta confirmarlo en real.
- Sin GFX9000, idéntica a f1c.
- f2i (madmix_f2i.zip): excavadora arriba/abajo con los dibujos de araubi (vista de frente y de espaldas, como en MSX1).

## f2j (2026-10-23): madmix_f2j.zip

- El logo de Topo con GFX9000 ya no se atasca: va al ritmo del TMS, saltando pasos si hace falta.
- En el menú, «2 JOYSTICK» se pone blanco al elegirlo (el espejo del V9990 no notaba ese cambio de color).
- READY? con fondo negro en el V9990.
- Excavadora hacia arriba y hacia abajo y trampillas: los dibujos del grafista, sacados de «or fase 1.png».
- En turbo R se pasa solo al R800 (sin probar aquí: no hay BIOS de turbo R).
- Sin GFX9000, idéntica a f1c.
- f2k (madmix_f2k.zip): arreglado el bote del laberinto entre FASE 1 y READY? con GFX9000 (el scroll se escribía con la imagen ya empezada).
- f2l (madmix_f2l.zip): logo de Topo con GFX9000 sin parones (cada byte se pinta al momento en el V9990); con el hipopótamo los fantasmas salen de su color y no azules. El R800 no acelera el juego: va a 10 tics/s fijos.
- f2m (madmix_f2m.zip): arreglado un fallo del juego original por el que una flecha podía contar dos veces y la fase acababa con un coco sin comer; quitado el bote al acabar el logo de Topo con GFX9000.
- f2n (madmix_f2n.zip): la mascota de The Pepsi Challenge con los dibujos del grafista (roja con el Super Coco; hacia arriba, roja por paleta).
- f2o (madmix_f2o.zip): las flechas vuelven a obligar a girar (lo rompió el arreglo de f2m); sigue sin contarse dos veces una flecha.
- f2p (madmix_f2p.zip): sin la raya de 1 píxel en el suelo al comer flechas (nivel 9 y algunos más).
- f2p_pasarfase (madmix_f2p_pasarfase.zip): ROM de pruebas igual que f2p, pero F1 pasa a la fase siguiente (una por pulsación).
- f2q (madmix_f2q.zip): en el nivel 13 se ve el icono de excavadora del punto de salida (el mapa del grafista no lo traía). Lleva también la ROM de pruebas con F1 para pasar de fase.
- f2r (madmix_f2r.zip): la flecha amarilla del nivel 14 pasa a blanca como las demás (venía así en el mapa del grafista). Con ROM de pruebas F1.
- f2s (madmix_f2s.zip): en el nivel 14 las dos casillas de excavadora del centro llevan su icono (la segunda venía mal en el mapa del grafista). Con ROM de pruebas F1.
- Prueba «volumen» sobre f2s (madmix_f2s_volumen.zip): muñecos sombreados con degradado de 3 tonos (amarillo, rosa y verde) usando la paleta 0-15 en partida; fantasmas y mascota de Pepsi sin cambios. Falta opinión de araubi y del grafista.

## MSX2 (2026-10-26)

araubi eligió SCREEN 5 con los gráficos del MSX1 por ahora (habrá otro grafista para MSX2).
- Fase 0 (msx2/madmix_msx2_fase0_velocidad.zip, pruebas/msx2/LEEME.md): fondo en anillo en la página 3 + ventana copiada + actores con LMMM. 50 Hz: 5 frames por tic (presupuesto 5) con 10 actores; 60 Hz: 6-7 (presupuesto 6). Recomponer todo cada tic tardaba 10: descartado.
- f2t (madmix_f2t.zip): el suelo que queda al comer los Super Cocos del nivel 1 lleva la sombra de su muro (a la derecha), igual que las casillas vecinas. Con ROM de pruebas F1.
- f2u (madmix_f2u.zip): el aplastacocos verde (fases 6 y 7) va 2 px a la derecha y queda centrado en los pasillos al subir y bajar. Con ROM de pruebas F1.
- f2v (madmix_f2v.zip): el tanque mirando a la izquierda ya no se desplaza 4 px a la derecha (el cuerpo queda donde mirando a la derecha). Con ROM de pruebas F1.
- f2w (madmix_f2w.zip): un bicho que se sale del laberinto (la mariquita de la fase 14, fallo del original) vuelve a su punto de salida; la bola junto a la flecha de la fase 15 (y una del 9 y otra del 11) lleva el suelo de las demás. Con ROM de pruebas F1.
- f2x (madmix_f2x.zip): el logo de Topo del marcador se ve entero (le faltaban sus 4 líneas de abajo). Con ROM de pruebas F1.
- Desde f2x cada zip lleva también la ROM con volumen (_volumen.rom, build.py --volumen).
- f2y (madmix_f2y.zip): MSX2 fase 1. Sin GFX9000, en un MSX2 con 128 KB de VRAM la partida sale en SCREEN 5: laberinto con las losetas del MSX1, su color, scroll y casillas comidas (los muñecos y el marcador, fase 2). Menús en SCREEN 2. V9990 y MSX1 sin cambios.
- f2z (madmix_f2z.zip): MSX2 fase 2. Sin la opción The Pepsi Challenge en MSX2. Muñecos con transparencia (idénticos píxel a píxel al MSX1), recuadro de color del comecocos, marco, vidas, puntos y textos FASE, READY? y ESTÁS FRITO. V9990 y MSX1 sin cambios.
- f30 (madmix_f30.zip): MSX2 a la misma velocidad que el MSX1 (antes cada tic tardaba casi el triple). V9990 y MSX1 sin cambios.
- f31 (madmix_f31.zip): en MSX2, el comecocos y los fantasmas mirando a la izquierda se ven bien. El zip ya no lleva la ROM con volumen.
- f32 (madmix_f32.zip): en MSX2, el menú vuelve a ser el del original (3 REDEFINE TECLAS, 4 DEMO).

## f33 (2026-10-28): The Pepsi Challenge, mascota roja con el Super Coco en MSX1
- ROM: `madmix_f33.zip` (normal + pasarfase). En el TMS el Super Coco ponía la mascota en amarillo (el color $30 del comecocos, igual que en la cinta original de Pepsi); ahora, con The Pepsi Challenge, va en rojo ($58) y parpadea rojo/blanco al final. Mad Mix Game sigue en amarillo y la GFX9000 no cambia (ya era roja).

## f34 (2026-10-28)
- ROM: `madmix_f34.zip` (normal, pasarfase y volumen).
- Con GFX9000, la salida MSX dejaba corrupta la pantalla de carga al empezar la música: V9_PORTADA volvía de V9_PONER_MODO con EI y la interrupción movía el puntero del TMS en mitad del volcado. Ahora DI.
- The Pepsi Challenge en GFX9000 (normal y volumen): hacia arriba con el Super Coco, la entrada 9 de la paleta de sprites (amarillo, solo de la mascota) pasa al rojo de los dibujos del grafista (V9_PEPSI_ROJA, pepsi_roja.asm en $0040/tras volumen.asm); antes usaba la paleta del TMS (otro rojo) y con volumen se quedaba amarilla.
