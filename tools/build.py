#!/usr/bin/env python3
"""
build.py -- Mad Mix Game v9990: compila la ROM completa.

  1. src/juego/imagen_ram.asm -> build/ram_1000.bin, ram_8400.bin,
     logotopo.bin (el juego en sus direcciones nativas de RAM).
  2. Trocea esos binarios en fragmentos de <= 2 KB que no cruzan
     limites de banco de 16 KB y genera:
       build/carga_util.bin   -- bancos 1..n de la megaROM
       build/tabla_carga.inc  -- TABLA_LOGO y TABLA_JUEGO para el cargador
  3. src/rom/rom.asm -> build/madmix_v9990.rom (ASCII16), rellenada a
     potencia de 2.

Uso: python3 tools/build.py   (requiere sjasmplus en el PATH)
"""
import os
import shutil
import subprocess
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD = os.path.join(RAIZ, "build")
BANCO = 0x4000
FRAG = 0x800

# (nombre de tabla, [(fichero, direccion destino)])
TABLAS = [
    ("TABLA_LOGO", [("logotopo.bin", 0x9470)]),
    ("TABLA_JUEGO", [("ram_1000.bin", 0x1000), ("ram_6500.bin", 0x6500),
                     ("ram_8400.bin", 0x8400)]),
]


def sjasmplus(cwd, fuente):
    exe = shutil.which("sjasmplus") or os.path.expanduser("~/.local/bin/sjasmplus")
    r = subprocess.run([exe, "--nologo", "--msg=war", fuente], cwd=cwd)
    if r.returncode:
        sys.exit(f"ERROR: sjasmplus fallo en {fuente}")


def main():
    os.makedirs(BUILD, exist_ok=True)
    sjasmplus(os.path.join(RAIZ, "src", "juego"), "imagen_ram.asm")

    carga = bytearray()          # empieza en el banco 1 (offset ROM $4000)
    lineas = ["; generado por tools/build.py -- no editar", ""]
    for nombre, tramos in TABLAS:
        lineas.append(f"{nombre}:")
        for fichero, destino in tramos:
            datos = open(os.path.join(BUILD, fichero), "rb").read()
            pos = 0
            while pos < len(datos):
                off_rom = BANCO + len(carga)
                banco, dentro = divmod(off_rom, BANCO)
                n = min(FRAG, len(datos) - pos, BANCO - dentro)
                carga += datos[pos:pos + n]
                lineas.append(
                    f"    DW ${destino + pos:04X} : DB {banco} : DW ${0x4000 + dentro:04X}, {n}")
                pos += n
        lineas.append("    DW 0")
        lineas.append("")
    open(os.path.join(BUILD, "carga_util.bin"), "wb").write(carga)
    open(os.path.join(BUILD, "tabla_carga.inc"), "w").write("\n".join(lineas))

    sjasmplus(os.path.join(RAIZ, "src", "rom"), "rom.asm")

    rom_path = os.path.join(BUILD, "madmix_v9990.rom")
    rom = bytearray(open(rom_path, "rb").read())
    if len(rom) != BANCO:
        sys.exit(f"ERROR: el banco 0 mide {len(rom)} bytes")
    rom += carga
    tam = 0x10000
    while tam < len(rom):
        tam *= 2
    rom += b"\xff" * (tam - len(rom))
    open(rom_path, "wb").write(rom)
    print(f"ROM: {rom_path} ({len(rom) // 1024} KB, ASCII16, {len(rom) // BANCO} bancos;"
          f" carga util {len(carga)} bytes)")


if __name__ == "__main__":
    main()
