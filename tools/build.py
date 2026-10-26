#!/usr/bin/env python3
"""
build.py -- Mad Mix Game v9990: compila la ROM completa.

  1. src/juego/imagen_ram.asm -> build/ram_1000.bin, ram_6500.bin,
     ram_8400.bin, ram_0100.bin, logotopo.bin (el juego en sus
     direcciones nativas de RAM).
  2. tools/graficos.py: los graficos del remake (graficos/remake) al
     formato del V9990 (build/v9_*.bin) y build/v9_datos.inc, que
     incluye v9990_ext.asm; por eso el paso 1 se repite despues.
  3. Trocea los binarios en fragmentos que no cruzan limites de banco
     de 16 KB y genera:
       build/carga_util.bin   -- bancos 1..n de la megaROM
       build/tabla_carga.inc  -- TABLA_LOGO, TABLA_JUEGO y TABLA_EXT (a
                                 RAM, fragmentos de <= 2 KB) y TABLA_V9990
                                 (a la VRAM del V9990, hasta 16 KB)
  4. src/rom/rom.asm -> build/madmix_v9990.rom (ASCII16), rellenada a
     potencia de 2.

Uso: python3 tools/build.py [--pruebas] [--pasarfase] [--volumen]   (requiere sjasmplus en el PATH)
     --pruebas: ROM con aleatoriedad determinista (ver imagen_ram.asm),
                build/madmix_v9990_pruebas.rom
     --pasarfase: ROM de pruebas en la que F1 da la fase por completada,
                build/madmix_v9990_pasarfase.rom
     --volumen: ROM de prueba con los munecos sombreados (volumen.asm),
                build/madmix_v9990_volumen.rom
"""
import os
import shutil
import subprocess
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD = os.path.join(RAIZ, "build")
BANCO = 0x4000
FRAG = 0x800
INICIO_CARGA = 0x1800          # offset en la ROM (banco 0, $5800) de la carga; igual que en rom.asm

# (nombre de tabla, [(fichero, direccion destino)])
TABLAS = [
    ("TABLA_LOGO", [("logotopo.bin", 0x9470)]),
    ("TABLA_JUEGO", [("ram_1000.bin", 0x1000), ("ram_6500.bin", 0x6500),
                     ("ram_7700.bin", 0x7700), ("ram_7ff0.bin", 0x7FF0),
                     ("ram_8400.bin", 0x8400), ("ram_dda1.bin", 0xDDA1),
                     ("ram_f010.bin", 0xF010)]),
    ("TABLA_EXT", [("ram_0100.bin", 0x0100), ("ram_0f00.bin", 0x0F00)]),
    # MSX2 sin GFX9000 (msx2.asm): encima de TABLA_EXT
    ("TABLA_M2", [("ram_m2_0100.bin", 0x0100), ("ram_f300.bin", 0xF300), ("ram_m2_alta.bin", 0x7E80)]),
]

# Pantalla de carga para el TMS cuando hay GFX9000 (rom.asm, V9_LOGO_PREPARAR):
# trozos de ram_1000.bin (la portada de MADMIX.SCR) que ya van en la ROM,
# (direccion en la imagen, bytes, destino en RAM)
PORTADA_TMS = [(0x10AC, 16, 0xA5F0),     # PALETA_COLORES_PORTADA
               (0x10ED, 6144, 0xA600),   # PORTADA_PATRON
               (0x28F0, 768, 0xBE00)]    # PORTADA_COLOR (comprimido)

# Graficos del V9990 (tools/graficos.py) y su direccion en la VRAM
VRAM = [("v9_capa_a.bin", 0x06000), ("v9_sprites.bin", 0x18000),
        ("v9_niveles.bin", 0x20000), ("v9_losetas.bin", 0x40000)]

DATOS_VACIOS = """; provisional (tools/build.py), lo sustituye tools/graficos.py
V9_PALETA_MARCO:   DS 48
V9_PALETA_SPRITES: DS 48
V9_TMS_A_MARCO:    DS 16
V9_META:           DS 256
"""


PRUEBAS = "--pruebas" in sys.argv
PASAR_FASE = "--pasarfase" in sys.argv
VOLUMEN = "--volumen" in sys.argv
if VOLUMEN:
    os.environ["MADMIX_VOLUMEN"] = "1"       # tools/graficos.py
    TABLAS[2][1].append(("ram_0040.bin", 0x0040))


def sjasmplus(cwd, fuente):
    exe = shutil.which("sjasmplus") or os.path.expanduser("~/.local/bin/sjasmplus")
    extra = ["-DPRUEBAS"] if PRUEBAS else []
    if PASAR_FASE:
        extra.append("-DPASAR_FASE")
    if VOLUMEN:
        extra.append("-DVOLUMEN")
    r = subprocess.run([exe, "--nologo", "--msg=war"] + extra + [fuente], cwd=cwd)
    if r.returncode:
        sys.exit(f"ERROR: sjasmplus fallo en {fuente}")


def main():
    os.makedirs(BUILD, exist_ok=True)
    datos = os.path.join(BUILD, "v9_datos.inc")
    if not os.path.exists(datos):
        open(datos, "w").write(DATOS_VACIOS)
    for f, vacio in (("v9_volumen.inc", "V9_PALETA_VOLUMEN: DS 48\n"), ("v9_portada.lz", b"\0"), ("pepsi_delta.bin", b"\0\0"), ("pepsi_subtablas.bin", b"\0\0"),
                     ("pepsi_indicadores.bin", b"\0\0"), ("v9_pepsi.inc", "V9_META_PEPSI: DS 72\nV9_META_ROJO_ARRIBA: DS 13\nV9_META_F_ROJO: DS 72\nV9_META_F_NARANJA: DS 72\n")):
        if not os.path.exists(os.path.join(BUILD, f)):
            open(os.path.join(BUILD, f), "wb" if isinstance(vacio, bytes) else "w").write(vacio)
    sjasmplus(os.path.join(RAIZ, "src", "juego"), "imagen_ram.asm")
    r = subprocess.run([sys.executable, os.path.join(RAIZ, "tools", "graficos.py")])
    if r.returncode:
        sys.exit("ERROR: tools/graficos.py fallo")
    sjasmplus(os.path.join(RAIZ, "src", "juego"), "imagen_ram.asm")

    carga = bytearray()          # empieza detras del cargador, en el banco 0
    lineas = ["; generado por tools/build.py -- no editar", ""]
    en_rom = {}                  # direccion en RAM -> (banco, direccion en la pagina 1)
    for nombre, tramos in TABLAS:
        lineas.append(f"{nombre}:")
        for fichero, destino in tramos:
            datos = open(os.path.join(BUILD, fichero), "rb").read()
            pos = 0
            while pos < len(datos):
                off_rom = INICIO_CARGA + len(carga)
                banco, dentro = divmod(off_rom, BANCO)
                n = min(FRAG, len(datos) - pos, BANCO - dentro)
                for k in range(n):
                    en_rom[destino + pos + k] = (banco, 0x4000 + dentro + k)
                carga += datos[pos:pos + n]
                lineas.append(
                    f"    DW ${destino + pos:04X} : DB {banco} : DW ${0x4000 + dentro:04X}, {n}")
                pos += n
        lineas.append("    DW 0")
        lineas.append("")
    # pantalla de carga para el TMS: los mismos bytes de la ROM, por trozos
    # que no cruzan un limite de banco
    lineas.append("TABLA_PORTADA_TMS:")
    for origen, n, destino in PORTADA_TMS:
        k = 0
        while k < n:
            banco, rom = en_rom[origen + k]
            m = 1
            while k + m < n and m < FRAG and en_rom[origen + k + m] == (banco, rom + m):
                m += 1
            lineas.append(f"    DW ${destino + k:04X} : DB {banco} : DW ${rom:04X}, {m}")
            k += m
    lineas.append("    DW 0")
    lineas.append("")
    # graficos del V9990: DB bits 16-18 : DW bits 0-15 : DB banco : DW origen, longitud
    lineas.append("TABLA_V9990:")
    for fichero, destino in VRAM:
        datos = open(os.path.join(BUILD, fichero), "rb").read()
        pos = 0
        while pos < len(datos):
            off_rom = INICIO_CARGA + len(carga)
            banco, dentro = divmod(off_rom, BANCO)
            n = min(len(datos) - pos, BANCO - dentro)
            carga += datos[pos:pos + n]
            v = destino + pos
            lineas.append(f"    DB {v >> 16} : DW ${v & 0xFFFF:04X} : DB {banco} : DW ${0x4000 + dentro:04X}, {n}")
            pos += n
    lineas.append("    DB $FF")
    lineas.append("")
    # portada del V9990 comprimida (lz.py): seguida, aunque cruce bancos
    off_rom = INICIO_CARGA + len(carga)
    banco, dentro = divmod(off_rom, BANCO)
    carga += open(os.path.join(BUILD, "v9_portada.lz"), "rb").read()
    lineas.append(f"PORTADA_V9990: DB {banco} : DW ${0x4000 + dentro:04X}")
    lineas.append("")
    open(os.path.join(BUILD, "carga_util.bin"), "wb").write(carga)
    open(os.path.join(BUILD, "tabla_carga.inc"), "w").write("\n".join(lineas))

    sjasmplus(os.path.join(RAIZ, "src", "rom"), "rom.asm")

    rom_path = os.path.join(BUILD, "madmix_v9990.rom")
    rom = bytearray(open(rom_path, "rb").read())
    if len(rom) != INICIO_CARGA:
        sys.exit(f"ERROR: el cargador mide {len(rom)} bytes")
    rom += carga
    tam = 0x10000
    while tam < len(rom):
        tam *= 2
    rom += b"\xff" * (tam - len(rom))
    if PRUEBAS:
        os.replace(rom_path, rom_path := rom_path.replace(".rom", "_pruebas.rom"))
    if PASAR_FASE:
        os.replace(rom_path, rom_path := rom_path.replace(".rom", "_pasarfase.rom"))
    if VOLUMEN:
        os.replace(rom_path, rom_path := rom_path.replace(".rom", "_volumen.rom"))
    open(rom_path, "wb").write(rom)
    print(f"ROM: {rom_path} ({len(rom) // 1024} KB, ASCII16, {len(rom) // BANCO} bancos;"
          f" carga util {len(carga)} bytes)")


if __name__ == "__main__":
    main()
