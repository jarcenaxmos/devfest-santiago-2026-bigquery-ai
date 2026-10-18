# SPDX-License-Identifier: MIT

"""Logging JSON para Cloud Logging y métricas Prometheus."""

import datetime
import json
import logging
import sys

import prometheus_client

SERVICIO = "devfest-timelapse"

REQUESTS_TOTAL = prometheus_client.Counter(
    "requests_total", "Total de requests HTTP", ["path", "status"]
)
REQUESTS_DURATION = prometheus_client.Histogram(
    "requests_duration_seconds", "Latencia de requests HTTP", ["path"]
)
ERRORS_TOTAL = prometheus_client.Counter(
    "errors_total", "Errores por tipo", ["type"]
)
IAP_AUTH_FAILURES = prometheus_client.Counter(
    "iap_auth_failures_total", "Requests que fallaron la validación IAP"
)

# Campos extra que se copian del LogRecord al JSON si existen.
_CAMPOS = (
    "user_email",
    "action",
    "ip_address",
    "request_path",
    "status_code",
    "correlation_id",
    "duration_ms",
    "detail",
)


class FormatoJson(logging.Formatter):
    """Formatea cada línea como JSON con 'severity' (Cloud Logging)."""

    def format(self, record: logging.LogRecord) -> str:
        entrada = {
            "severity": record.levelname.replace("WARNING", "WARN"),
            "timestamp": datetime.datetime.fromtimestamp(
                record.created, tz=datetime.timezone.utc
            ).isoformat(),
            "service_name": SERVICIO,
            "message": record.getMessage(),
            "logger": record.name,
        }
        for campo in _CAMPOS:
            if hasattr(record, campo):
                entrada[campo] = getattr(record, campo)
        if record.exc_info:
            entrada["exception"] = self.formatException(record.exc_info)
        return json.dumps(entrada, ensure_ascii=False)


def configurar_logging() -> None:
    """Instala el formateador JSON en el logger raíz (stdout)."""
    manejador = logging.StreamHandler(sys.stdout)
    manejador.setFormatter(FormatoJson())
    raiz = logging.getLogger()
    raiz.handlers = [manejador]
    raiz.setLevel(logging.INFO)
    # uvicorn trae sus propios handlers: los redirigimos al JSON.
    for nombre in ("uvicorn", "uvicorn.error"):
        logging.getLogger(nombre).handlers = [manejador]
        logging.getLogger(nombre).propagate = False
    logging.getLogger("uvicorn.access").disabled = True
