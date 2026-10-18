# SPDX-License-Identifier: MIT

"""Servicio FastAPI del timelapse "Santiago desde el espacio".

Rutas:
    GET /                       página (estático)
    GET /api/datos?evento=13oct datos precalculados (Gemini + SEC + cuadros)
    GET /api/cuadro/{evento}/{utc}.jpg  bytes del cuadro desde memoria
    GET /health /ready /metrics observabilidad (sin validación IAP: probes)
"""

import contextlib
import json
import logging
import os
import pathlib
import threading
import time
import uuid

import fastapi
import fastapi.responses
import fastapi.staticfiles
import prometheus_client

from app import cuadros
from app import observabilidad
from app import seguridad

BASE = pathlib.Path(__file__).resolve().parent
BUCKET = os.environ.get("BUCKET", "devfest-demo-bq-lab")
DATOS_PATH = pathlib.Path(
    os.environ.get("DATOS", str(BASE.parent / "data" / "eventos.json"))
)
# Solo para desarrollo local: en Cloud Run siempre "true".
IAP_REQUERIDO = os.environ.get("IAP_REQUERIDO", "true").lower() == "true"
IAP_AUDIENCIA = os.environ.get("IAP_AUDIENCIA", "")
RUTAS_SIN_IAP = frozenset({"/health", "/ready", "/metrics"})

observabilidad.configurar_logging()
logger = logging.getLogger("timelapse")

with DATOS_PATH.open(encoding="utf-8") as _archivo:
    EVENTOS: dict = json.load(_archivo)

CACHE = cuadros.CacheCuadros(
    BUCKET,
    [c["objeto"] for ev in EVENTOS.values() for c in ev["cuadros"]],
)
VALIDADOR = seguridad.ValidadorIap(IAP_AUDIENCIA)


@contextlib.asynccontextmanager
async def ciclo_de_vida(_: fastapi.FastAPI):
    """Lanza la precarga de cuadros en segundo plano al iniciar."""
    if IAP_REQUERIDO and not IAP_AUDIENCIA:
        # SAFETY: sin audiencia no podemos validar el JWT; mejor no arrancar.
        raise RuntimeError("IAP_AUDIENCIA es obligatoria si IAP_REQUERIDO")
    threading.Thread(target=CACHE.precargar, daemon=True).start()
    yield


app = fastapi.FastAPI(
    title="devfest-timelapse",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
    lifespan=ciclo_de_vida,
)


@app.middleware("http")
async def iap_y_metricas(request: fastapi.Request, call_next):
    """Valida IAP en cada request (salvo probes) y registra métricas."""
    inicio = time.perf_counter()
    correlacion = request.headers.get(
        "x-cloud-trace-context", uuid.uuid4().hex
    ).split("/")[0]
    ruta = request.url.path
    ip = request.headers.get(
        "x-forwarded-for", request.client.host if request.client else ""
    )
    email = "local-dev"
    if ruta not in RUTAS_SIN_IAP and IAP_REQUERIDO:
        try:
            email = VALIDADOR.validar(
                request.headers.get("x-goog-iap-jwt-assertion")
            )
        except seguridad.ErrorIap as exc:
            observabilidad.IAP_AUTH_FAILURES.inc()
            logger.warning(
                "Validación IAP fallida",
                extra={
                    "action": "iap_rechazado",
                    "request_path": ruta,
                    "ip_address": ip,
                    "status_code": 401,
                    "correlation_id": correlacion,
                    "detail": str(exc),
                },
            )
            return fastapi.responses.JSONResponse(
                {"error": {"code": 401, "message": "IAP requerido"}},
                status_code=401,
            )
    request.state.email = email
    try:
        respuesta = await call_next(request)
    except Exception:
        observabilidad.ERRORS_TOTAL.labels(type="excepcion").inc()
        raise
    plantilla = "/" if ruta in ("/", "/index.html") else getattr(
        request.scope.get("route"), "path", "estatico"
    )
    duracion = time.perf_counter() - inicio
    observabilidad.REQUESTS_TOTAL.labels(
        path=plantilla, status=str(respuesta.status_code)
    ).inc()
    observabilidad.REQUESTS_DURATION.labels(path=plantilla).observe(duracion)
    if respuesta.status_code >= 500:
        observabilidad.ERRORS_TOTAL.labels(type="http_5xx").inc()
    # Auditoría: solo acciones con sentido (no cada cuadro ni cada probe).
    if plantilla in ("/", "/api/datos"):
        logger.info(
            "Acceso",
            extra={
                "user_email": email,
                "action": "abrio_pagina" if plantilla == "/" else "leyo_datos",
                "ip_address": ip,
                "request_path": str(request.url.path),
                "status_code": respuesta.status_code,
                "correlation_id": correlacion,
                "duration_ms": round(duracion * 1000, 1),
            },
        )
    return respuesta


@app.get("/health")
def health() -> dict:
    """Liveness: el proceso responde."""
    return {"status": "ok"}


@app.get("/ready")
def ready() -> fastapi.responses.JSONResponse:
    """Readiness: los cuadros ya están en memoria."""
    if CACHE.lista.is_set():
        return fastapi.responses.JSONResponse({"status": "ready"})
    estado = {"status": "cargando", "error": CACHE.error}
    return fastapi.responses.JSONResponse(estado, status_code=503)


@app.get("/metrics")
def metrics() -> fastapi.Response:
    """Métricas Prometheus."""
    return fastapi.Response(
        prometheus_client.generate_latest(),
        media_type=prometheus_client.CONTENT_TYPE_LATEST,
    )


@app.get("/api/datos")
def datos(evento: str = "13oct") -> fastapi.responses.JSONResponse:
    """Datos precalculados de un evento.

    Args:
        evento: "13oct" o "08oct".
    """
    if evento not in EVENTOS:
        raise fastapi.HTTPException(404, "evento desconocido")
    return fastapi.responses.JSONResponse(
        EVENTOS[evento], headers={"Cache-Control": "private, max-age=300"}
    )


@app.get("/api/eventos")
def eventos() -> list[dict]:
    """Lista de eventos para el selector."""
    return [
        {"id": ev["id"], "etiqueta": ev["etiqueta"]} for ev in EVENTOS.values()
    ]


@app.get("/api/cuadro/{evento}/{utc}.jpg")
def cuadro(evento: str, utc: str) -> fastapi.Response:
    """Bytes de un cuadro, servidos desde la caché en memoria.

    Args:
        evento: Clave del evento.
        utc: Hora UTC HHMM del cuadro.
    """
    ev = EVENTOS.get(evento)
    if ev is None or not (len(utc) == 4 and utc.isdigit()):
        raise fastapi.HTTPException(404, "cuadro desconocido")
    objeto = f"wow/{ev['fecha']}/{utc}.jpg"
    contenido = CACHE.obtener(objeto)
    if contenido is None:
        raise fastapi.HTTPException(404, "cuadro no disponible")
    return fastapi.Response(
        contenido,
        media_type="image/jpeg",
        headers={"Cache-Control": "private, max-age=86400, immutable"},
    )


app.mount(
    "/",
    fastapi.staticfiles.StaticFiles(directory=BASE / "static", html=True),
    name="static",
)
