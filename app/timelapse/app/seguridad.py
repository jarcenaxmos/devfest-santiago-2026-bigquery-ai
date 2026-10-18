# SPDX-License-Identifier: MIT

"""Validación de la identidad que entrega IAP (directo en Cloud Run).

IAP firma cada request con x-goog-iap-jwt-assertion (ES256). Validamos firma,
emisor y audiencia; la audiencia de IAP en Cloud Run es
/projects/PROJECT_NUMBER/locations/REGION/services/SERVICE
(https://docs.cloud.google.com/iap/docs/signed-headers-howto).
"""

import json
import logging
import threading
import time
import urllib.request

import google.auth.exceptions
import google.auth.jwt

LLAVES_URL = "https://www.gstatic.com/iap/verify/public_key"
EMISOR = "https://cloud.google.com/iap"
_TTL_LLAVES = 3600

logger = logging.getLogger(__name__)


class ErrorIap(ValueError):
    """La request no trae una identidad IAP válida."""


class ValidadorIap:
    """Valida el JWT de IAP con las llaves públicas cacheadas una hora."""

    def __init__(self, audiencia: str) -> None:
        """Crea el validador.

        Args:
            audiencia: Audiencia esperada del JWT (ver docstring del módulo).
        """
        self._audiencia = audiencia
        self._llaves: dict[str, str] = {}
        self._vence = 0.0
        self._lock = threading.Lock()

    def _obtener_llaves(self) -> dict[str, str]:
        with self._lock:
            if time.monotonic() > self._vence:
                with urllib.request.urlopen(LLAVES_URL, timeout=5) as resp:
                    self._llaves = json.loads(resp.read())
                self._vence = time.monotonic() + _TTL_LLAVES
            return self._llaves

    def validar(self, jwt_iap: str | None) -> str:
        """Devuelve el email autenticado o lanza ErrorIap.

        Args:
            jwt_iap: Valor del header x-goog-iap-jwt-assertion.

        Returns:
            Email del usuario (sin prefijo accounts.google.com:).

        Raises:
            ErrorIap: Si falta el JWT o no es válido.
        """
        if not jwt_iap:
            raise ErrorIap("falta x-goog-iap-jwt-assertion")
        try:
            datos = google.auth.jwt.decode(
                jwt_iap,
                certs=self._obtener_llaves(),
                audience=self._audiencia,
                clock_skew_in_seconds=30,
            )
        except (ValueError, google.auth.exceptions.GoogleAuthError) as exc:
            raise ErrorIap(f"JWT IAP inválido: {exc}") from exc
        if datos.get("iss") != EMISOR:
            raise ErrorIap("emisor inesperado")
        email = datos.get("email", "")
        if not email:
            raise ErrorIap("JWT sin email")
        return email.removeprefix("accounts.google.com:")
