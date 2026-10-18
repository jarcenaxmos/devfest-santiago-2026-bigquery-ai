-- 10 · Cómo leer un pronóstico: valor (mediana) vs límite superior, con y sin "ojos".
-- Origen: 13-oct 18:00 UTC (15:00 hora Chile), una hora antes del salto. Horizonte 6 h.
--   ciego    = TimesFM 3.0 solo con la serie de clientes sin luz.
--   con_ojos = TimesFM 3.0 + covariables pasadas del satélite (intensidad,
--              nubosidad, convección que Gemini vio hasta las 15:00).
-- *_sup = prediction_interval_upper_bound (intervalo al 95 %, confidence_level 0.95).
-- Script: ejecútalo completo.

DECLARE origen TIMESTAMP DEFAULT TIMESTAMP '2026-10-13 18:00:00+00';

CREATE TEMP TABLE serie AS
SELECT s.ts_utc,
  IF(s.ts_utc > origen, NULL, s.clientes_afectados) AS clientes,
  IF(s.ts_utc > origen, NULL, LAST_VALUE(v.intensidad IGNORE NULLS) OVER w) AS sat_intensidad,
  IF(s.ts_utc > origen, NULL, LAST_VALUE(v.nubosidad_pct IGNORE NULLS) OVER w) AS sat_nubosidad,
  IF(s.ts_utc > origen, NULL, LAST_VALUE(CAST(v.conveccion AS INT64) IGNORE NULLS) OVER w) AS sat_conveccion
FROM fuentes.sec_rm_horario AS s
LEFT JOIN fuentes.satelite_horario AS v ON v.ts_utc = s.ts_utc
WHERE s.ts_utc <= TIMESTAMP_ADD(origen, INTERVAL 6 HOUR)
WINDOW w AS (ORDER BY s.ts_utc ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW);

CREATE OR REPLACE TABLE trabajo.pronostico_bandas AS
WITH ciego AS (
  SELECT forecast_timestamp AS ts_utc, forecast_value AS v,
    prediction_interval_upper_bound AS sup, confidence_level
  FROM AI.FORECAST((SELECT ts_utc, clientes FROM serie WHERE ts_utc <= origen),
    data_col => 'clientes', timestamp_col => 'ts_utc', horizon => 6, model => 'TimesFM 3.0')),
con_ojos AS (
  SELECT ts_utc, clientes.value AS v, clientes.prediction_interval_upper_bound AS sup
  FROM AI.FORECAST(TABLE serie, target_cols => ['clientes'], timestamp_col => 'ts_utc',
    model => 'TimesFM 3.0', horizon => 6, context_window => 1024,
    past_covariate_cols => ['sat_intensidad', 'sat_nubosidad', 'sat_conveccion'])
  WHERE time_series_type = 'forecast')
SELECT c.ts_utc,
  DATETIME(c.ts_utc, 'America/Santiago') AS ts_chile,
  r.clientes_afectados AS real,
  CAST(c.v AS INT64) AS ciego, CAST(c.sup AS INT64) AS ciego_sup,
  CAST(o.v AS INT64) AS con_ojos, CAST(o.sup AS INT64) AS con_ojos_sup,
  c.confidence_level
FROM ciego AS c
JOIN con_ojos AS o USING (ts_utc)
JOIN fuentes.sec_rm_horario AS r USING (ts_utc);

SELECT FORMAT_DATETIME('%H:%M', ts_chile) AS hora_chile,
  real, ciego, ciego_sup, con_ojos, con_ojos_sup,
  real > GREATEST(ciego_sup, con_ojos_sup) AS fuera_de_la_banda
FROM trabajo.pronostico_bandas
ORDER BY ts_utc;
