# Pruebas en openMSX

`msxshot.sh <rom> <segundos> <salida.png> [MSX|GFX9000] [ASCII16]` arranca
la ROM en una máquina C-BIOS MSX1 con la extensión `gfx9000`, sin pantalla,
y guarda capturas. La variable `MSX_SHOTS="t1 t2 ..."` añade capturas
intermedias y `MSX_TCL=fichero` carga un guion Tcl, por ejemplo pulsaciones
de tecla.

`partida_qaop.tcl` recorre portada → menú (1 Teclado, 0 Jugar) → partida y
mueve al comecocos con P, A y O (eran los controles del original; desde
f0d/f1b los de serie son los cursores y el espacio).

```
MSX_TCL=pruebas/partida_qaop.tcl MSX_SHOTS="25 28 31" \
  pruebas/msxshot.sh build/madmix_v9990.rom 34 /tmp/p.png MSX ASCII16
```

Con `MSX_SIN_GFX9000=1` la máquina arranca sin el cartucho GFX9000.
Para ver la salida del V9990 se pasa `GFX9000` como fuente de vídeo.

`perfil.sh` recibe las marcas de tiempo como cuarto argumento, no por
variable de entorno. Con la demo (`PERF_MODO=demo`, ROM `--pruebas`):
`"L:<ESPERAR_TIC> I:0x882A"`; `ESPERAR_TIC` está en `0x6542` en f0c/f0d,
`0x6545` en F1/f1b, `0x6546` en f0e y `0x6549` en f1c. Con
`PERF_HASH=1` y `compara_estado.py` se comparan dos versiones tic a tic
(alinear por el primer tic común si empiezan desfasadas).

**Cortes del volcado.** Para ver si algún fotograma sale a medio
escribir hay que capturar cada frame con `throttle on` (con `throttle
off` openMSX se salta fotogramas) y buscar fotogramas que difieran del
anterior y del siguiente en la zona de la ventana.

Las rutas del binario de openMSX dentro de `msxshot.sh` son las del entorno
de trabajo de Claude; en otro equipo hay que ajustarlas.
