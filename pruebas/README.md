# Pruebas en openMSX

`msxshot.sh <rom> <segundos> <salida.png> [MSX|GFX9000] [ASCII16]` arranca
la ROM en una máquina C-BIOS MSX1 con la extensión `gfx9000`, sin pantalla,
y guarda capturas. La variable `MSX_SHOTS="t1 t2 ..."` añade capturas
intermedias y `MSX_TCL=fichero` carga un guion Tcl, por ejemplo pulsaciones
de tecla.

`partida_qaop.tcl` recorre portada → menú (1 Teclado, 0 Jugar) → partida y
mueve al comecocos con P, A y O (los controles del juego son Q/A/O/P y
espacio).

```
MSX_TCL=pruebas/partida_qaop.tcl MSX_SHOTS="25 28 31" \
  pruebas/msxshot.sh build/madmix_v9990.rom 34 /tmp/p.png MSX ASCII16
```

Con `MSX_SIN_GFX9000=1` la máquina arranca sin el cartucho GFX9000.
Para ver la salida del V9990 se pasa `GFX9000` como fuente de vídeo.

`perfil.sh` recibe las marcas de tiempo como cuarto argumento, no por
variable de entorno. En F1, con la demo: `"L:0x6545 I:0x882A"`
(`ESPERAR_TIC`; en f0c es `0x6542`).

Las rutas del binario de openMSX dentro de `msxshot.sh` son las del entorno
de trabajo de Claude; en otro equipo hay que ajustarlas.
