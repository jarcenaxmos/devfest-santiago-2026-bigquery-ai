# SPDX-License-Identifier: MIT

"""Precalcula los datos de la app leyendo BigQuery UNA vez (en build).

Lee devfest_lab.satelite_horario y devfest_lab.sec_rm_horario con el CLI
`bq` (credenciales del usuario, no de la app) y escribe data/eventos.json,
que se copia en la imagen. Así la app en Cloud Run no consulta BigQuery y su
cuenta de servicio no necesita permisos de BigQuery.

Uso (desde app/timelapse/):
    python3 -I scripts/exportar_datos.py data/eventos.json
"""

import json
import subprocess
import sys
from typing import Any

PROYECTO = "devfest-demo-bq"
UBICACION = "us-east1"
BUCKET_PREFIJO = "wow"

# Hitos narrativos: hora Chile "HH:MM" y texto corto. Cifras verificadas en
# BigQuery: 13-oct 17:00 = 40.366 clientes.
EVENTOS: dict[str, dict[str, Any]] = {
    "13oct": {
        "fecha": "2026-10-13",
        "titulo": "Santiago desde el espacio · 13 oct 2026",
        "etiqueta": "13-oct tormenta",
        "utc_desde": 16,
        "utc_hasta": 23,
        "hitos": [
            {"hora": "15:00", "texto": "Gemini: intensidad 4"},
            {"hora": "16:00", "texto": "Célula sobre Santiago"},
            {"hora": "17:00", "texto": "Peak 40.366 sin luz"},
        ],
    },
    "08oct": {
        "fecha": "2026-10-08",
        "titulo": "Santiago desde el espacio · 8 oct 2026",
        "etiqueta": "8-oct aluvión",
        "utc_desde": 17,
        "utc_hasta": 22,
        "hitos": [
            {"hora": "17:00", "texto": "~Aluvión Quebrada Honda"},
        ],
    },
}

# Hora Chile = UTC-3 en octubre de 2026 (horario de verano desde 6-sep).
DESFASE_CHILE = -3


def consultar(sql: str) -> list[dict]:
    """Ejecuta una consulta con el CLI bq y devuelve las filas como dicts.

    Args:
        sql: Consulta en GoogleSQL.

    Returns:
        Lista de filas.

    Raises:
        subprocess.CalledProcessError: Si bq falla.
    """
    salida = subprocess.run(
        [
            "bq",
            f"--project_id={PROYECTO}",
            f"--location={UBICACION}",
            "query",
            "--nouse_legacy_sql",
            "--format=json",
            "--max_rows=1000",
            sql,
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return json.loads(salida)


def satelite(fecha: str) -> list[dict]:
    """Lecturas horarias de Gemini para un día (hora Chile)."""
    filas = consultar(
        "SELECT FORMAT_DATETIME('%H:%M', ts_chile) AS hora, intensidad, "
        "nubosidad_pct, conveccion, celula_sobre_santiago, tipo, "
        "descripcion FROM devfest_lab.satelite_horario "
        f"WHERE DATE(ts_chile) = '{fecha}' ORDER BY ts_chile"
    )
    return [
        {
            "hora": f["hora"],
            "intensidad": int(f["intensidad"]),
            "nubosidadPct": int(f["nubosidad_pct"]),
            "conveccion": f["conveccion"] == "true",
            "celulaSobreSantiago": f.get("celula_sobre_santiago") == "true",
            "tipo": f["tipo"],
            "descripcion": f["descripcion"],
        }
        for f in filas
    ]


def sec(fecha: str) -> list[dict]:
    """Clientes sin luz en la RM por hora para un día (hora Chile)."""
    filas = consultar(
        "SELECT FORMAT_DATETIME('%H:%M', ts_chile) AS hora, "
        "clientes_afectados, comunas_afectadas "
        "FROM devfest_lab.sec_rm_horario "
        f"WHERE DATE(ts_chile) = '{fecha}' ORDER BY ts_chile"
    )
    return [
        {
            "hora": f["hora"],
            "clientes": int(f["clientes_afectados"]),
            "comunas": int(f["comunas_afectadas"]),
        }
        for f in filas
    ]


def cuadros(evento: dict) -> list[dict]:
    """Lista de cuadros cada 10 min con su hora UTC y Chile."""
    lista = []
    for hora in range(evento["utc_desde"], evento["utc_hasta"] + 1):
        for minuto in range(0, 60, 10):
            hhmm = f"{hora:02d}{minuto:02d}"
            hora_chile = (hora + DESFASE_CHILE) % 24
            lista.append(
                {
                    "utc": hhmm,
                    "horaChile": f"{hora_chile:02d}:{minuto:02d}",
                    "objeto": f"{BUCKET_PREFIJO}/{evento['fecha']}/{hhmm}.jpg",
                }
            )
    return lista


def main(destino: str) -> None:
    """Escribe el JSON con todos los eventos."""
    datos: dict[str, dict[str, Any]] = {}
    for clave, evento in EVENTOS.items():
        datos[clave] = {
            "id": clave,
            "fecha": evento["fecha"],
            "titulo": evento["titulo"],
            "etiqueta": evento["etiqueta"],
            "hitos": evento["hitos"],
            "cuadros": cuadros(evento),
            "satelite": satelite(evento["fecha"]),
            "sec": sec(evento["fecha"]),
        }
        print(
            clave,
            len(datos[clave]["cuadros"]),
            "cuadros,",
            len(datos[clave]["satelite"]),
            "h satélite,",
            len(datos[clave]["sec"]),
            "h SEC",
        )
    with open(destino, "w", encoding="utf-8") as archivo:
        json.dump(datos, archivo, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
