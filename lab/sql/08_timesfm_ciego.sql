-- 08 · TimesFM "ciego": pronostica los clientes sin luz del 13-oct sabiendo solo el pasado.
-- Historia = fuentes.sec_rm_horario hasta el 13-oct 15:00 UTC (12:00 hora Chile).
-- Usamos ts_utc (serie continua): ts_chile tiene un salto por el cambio de hora del 6-sep.
-- Sin CREATE MODEL: TimesFM viene integrado en AI.FORECAST.

-- 8a · Pronóstico de 12 horas, guardado en trabajo
CREATE OR REPLACE TABLE trabajo.pronostico_ciego AS
SELECT *
FROM AI.FORECAST(
  (SELECT ts_utc, clientes_afectados
   FROM fuentes.sec_rm_horario
   WHERE ts_utc < TIMESTAMP '2026-10-13 15:00:00+00'),
  data_col => 'clientes_afectados',
  timestamp_col => 'ts_utc',
  horizon => 12,
  model => 'TimesFM 3.0');
-- La columna ai_forecast_status sale vacía: eso es ÉXITO. Según la doc oficial,
-- "This value is empty if the operation was successful"; si algo falla, trae el
-- texto del error (p. ej. "The time series data is too short").
-- https://docs.cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-ai-forecast

-- 8b · Pronóstico vs lo que pasó
SELECT FORMAT_TIMESTAMP('%d-%m %H:%M', p.forecast_timestamp, 'America/Santiago') AS hora_chile,
  r.clientes_afectados AS real,
  CAST(p.forecast_value AS INT64) AS pronostico,
  CAST(p.prediction_interval_upper_bound AS INT64) AS limite_superior,
  p.ai_forecast_status
FROM trabajo.pronostico_ciego AS p
JOIN fuentes.sec_rm_horario AS r ON r.ts_utc = p.forecast_timestamp
ORDER BY p.forecast_timestamp;
