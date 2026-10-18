# SPDX-License-Identifier: MIT

"""Caché en memoria de los cuadros del timelapse leídos del bucket privado.

Son 84 JPG (~30 MB en total): se descargan una vez al iniciar con la cuenta de
servicio y se sirven desde memoria. Así el play no depende de GCS en vivo y no
hace falta firmar URLs (firmar exigiría signBlob sobre la propia SA).
"""

import concurrent.futures
import logging
import threading

import google.cloud.storage

logger = logging.getLogger(__name__)


class CacheCuadros:
    """Descarga y guarda en memoria los objetos pedidos."""

    def __init__(self, bucket: str, objetos: list[str]) -> None:
        """Crea la caché.

        Args:
            bucket: Nombre del bucket (sin gs://).
            objetos: Rutas de objeto a precargar.
        """
        self._bucket = bucket
        self._objetos = objetos
        self._datos: dict[str, bytes] = {}
        self._lock = threading.Lock()
        self.lista = threading.Event()
        self.error: str | None = None

    def precargar(self) -> None:
        """Descarga todos los objetos en paralelo (bloqueante)."""
        cliente = google.cloud.storage.Client()
        bucket = cliente.bucket(self._bucket)

        def bajar(objeto: str) -> None:
            contenido = bucket.blob(objeto).download_as_bytes(timeout=30)
            with self._lock:
                self._datos[objeto] = contenido

        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
                list(pool.map(bajar, self._objetos))
        except Exception as exc:  # pylint: disable=broad-exception-caught
            # Intent: cualquier fallo de GCS deja /ready en 503 con el motivo,
            # en vez de matar el proceso; /health sigue vivo para depurar.
            self.error = f"{type(exc).__name__}: {exc}"
            logger.exception("Falló la precarga de cuadros")
            return
        total = sum(len(v) for v in self._datos.values())
        logger.info(
            "Cuadros precargados",
            extra={"detail": {"cuadros": len(self._datos), "bytes": total}},
        )
        self.lista.set()

    def obtener(self, objeto: str) -> bytes | None:
        """Devuelve los bytes del objeto si está en caché."""
        with self._lock:
            return self._datos.get(objeto)
