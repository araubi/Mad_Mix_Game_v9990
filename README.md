# Mad Mix Game v9990

Versión de *Mad Mix Game* (Topo Soft, 1988) para MSX1 con el
cartucho de vídeo **GFX9000 (Yamaha V9990)**, distribuida como
megaROM ASCII16. El diseño y las fases están en [DISENO.md](DISENO.md).

## Compilar

Requisitos: [SjASMPlus](https://github.com/z00m128/sjasmplus) y Python 3.

```
python3 tools/build.py
```

Genera `build/madmix_v9990.rom`. En openMSX hay que cargarla como
ASCII16 (`-romtype ASCII16`) en una máquina MSX1 con 64 KB, y la
extensión GFX9000 desde la fase F1.

## Estructura

- `src/juego/` — fuentes del juego (desensamblado de la base, con los
  cambios de este proyecto) e `imagen_ram.asm`, que lo ensambla en sus
  direcciones de RAM nativas.
- `src/rom/rom.asm` — cabecera y cargador del cartucho.
- `tools/build.py` — compila todo, trocea la carga útil y monta la ROM.

## Créditos y licencia

- **Juego original**: *Mad Mix Game*, © Topo Soft. Programación
  "Raphael Gomezzz", gráficos Roberto P. Acebes, música "Comilonas"
  (según los créditos del propio juego). Los derechos del juego
  siguen siendo de sus titulares; este repositorio no incluye
  imágenes del soporte original.
- **Desensamblado, etiquetas, comentarios y herramientas de la
  base**: Rafael Eduardo Martín Candial —
  [github.com/raemca/MSX_MadMixGame](https://github.com/raemca/MSX_MadMixGame),
  CC BY-NC-SA 4.0. Los ficheros de `src/juego/` proceden de ahí
  (commit `a90cf51`), con los cambios que se indican en cada sitio.
- **Corrección del nivel 13/14 y pila en `$F2FF`**: Manuel Pazos (2013).

Como obra derivada, la contribución de este proyecto se publica también
bajo **CC BY-NC-SA 4.0**, sin uso comercial.
