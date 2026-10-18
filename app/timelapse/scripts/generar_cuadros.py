# SPDX-License-Identifier: MIT

"""Genera los cuadros limpios (sin texto) del timelapse desde GOES-19 7200 px.

Usa el mismo recorte que slides/assets/wow/make_wow.py (1600x900 nativo,
centrado en Santiago) pero SIN hora ni marcador: la app los dibuja encima.

Uso:
    python3 -I generar_cuadros.py <dir GEOCOLOR_7200> <dir salida>

Salida: <salida>/2026-10-13/HHMM.jpg y <salida>/2026-10-08/HHMM.jpg (UTC).
Subir después con:
    gcloud storage cp -r <salida>/* gs://devfest-demo-bq-lab/wow/ \
        --project=devfest-demo-bq
"""

import os
import sys

from PIL import Image

# Santiago en la grilla 7200x4320 del sector ssa (verificado con luces
# nocturnas; ver slides/assets/wow/README.md).
SANTIAGO_X, SANTIAGO_Y = 2284, 2060
ANCHO, ALTO = 1600, 900

# (fecha, día juliano, hora UTC inicial, hora UTC final inclusive)
EVENTOS = (
    ("2026-10-13", 286, 16, 23),
    ("2026-10-08", 281, 17, 22),
)


def caja() -> tuple[int, int, int, int]:
    """Devuelve la caja de recorte centrada en Santiago."""
    x0 = SANTIAGO_X - ANCHO // 2
    y0 = SANTIAGO_Y - ALTO // 2
    return (x0, y0, x0 + ANCHO, y0 + ALTO)


def main(origen: str, destino: str) -> None:
    """Recorta y guarda todos los cuadros de los dos eventos.

    Args:
        origen: Carpeta con los JPG GEOCOLOR 7200x4320.
        destino: Carpeta donde se escriben los recortes.
    """
    for fecha, doy, h0, h1 in EVENTOS:
        carpeta = os.path.join(destino, fecha)
        os.makedirs(carpeta, exist_ok=True)
        for hora in range(h0, h1 + 1):
            for minuto in range(0, 60, 10):
                hhmm = f"{hora:02d}{minuto:02d}"
                nombre = f"2026{doy}{hhmm}_GOES19-ABI-ssa-GEOCOLOR-7200x4320.jpg"
                ruta = os.path.join(origen, nombre)
                if not os.path.exists(ruta):
                    print(f"falta {nombre}", file=sys.stderr)
                    continue
                with Image.open(ruta) as img:
                    recorte = img.convert("RGB").crop(caja())
                    recorte.save(
                        os.path.join(carpeta, f"{hhmm}.jpg"),
                        quality=84,
                        optimize=True,
                        progressive=True,
                    )
        print(fecha, len(os.listdir(carpeta)), "cuadros")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
