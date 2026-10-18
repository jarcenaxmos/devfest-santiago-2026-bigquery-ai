# Changelog

Formato [Keep a Changelog](https://keepachangelog.com/), versionado semántico.

## [Unreleased]

## [0.1.0] - 2026-10-15

### Added
- Timelapse GOES-19 (13-oct y 8-oct) con play/pausa, slider con hitos, velocidad y atajos de teclado.
- Tarjeta "Lo que vio Gemini" y gráfico de clientes sin luz (SEC) sincronizados con el cursor.
- Datos precalculados desde BigQuery (`scripts/exportar_datos.py`) y cuadros limpios (`scripts/generar_cuadros.py`).
- Despliegue en Cloud Run `devfest-timelapse` (us-east1) con IAP directo y validación del JWT de IAP.
- `/health`, `/ready`, `/metrics` y logging JSON con auditoría.
