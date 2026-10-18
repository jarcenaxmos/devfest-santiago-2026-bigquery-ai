-- 09 · AI.DETECT_ANOMALIES: ¿qué horas de octubre se salen de lo "normal"?
-- Lo normal = septiembre completo (historia). TimesFM pronostica cada hora de
-- octubre con su banda; si el valor real cae fuera de la banda, is_anomaly = TRUE.
-- Corte: 1-oct 00:00 hora Chile = 2026-10-01 03:00 UTC.

-- 9a · Detectar y guardar en trabajo
CREATE OR REPLACE TABLE trabajo.anomalias_luz AS
SELECT *
FROM AI.DETECT_ANOMALIES(
  (SELECT ts_utc, clientes_afectados FROM fuentes.sec_rm_horario
   WHERE ts_utc < TIMESTAMP '2026-10-01 03:00:00+00'),   -- historia: septiembre
  (SELECT ts_utc, clientes_afectados FROM fuentes.sec_rm_horario
   WHERE ts_utc >= TIMESTAMP '2026-10-01 03:00:00+00'),  -- a revisar: octubre
  data_col => 'clientes_afectados',
  timestamp_col => 'ts_utc',
  model => 'TimesFM 3.0');

-- 9b · Horas anómalas por día (hora Chile)
SELECT DATE(time_series_timestamp, 'America/Santiago') AS dia,
  COUNTIF(is_anomaly) AS horas_anomalas,
  MAX(CAST(time_series_data AS INT64)) AS peak_dia
FROM trabajo.anomalias_luz
GROUP BY dia
ORDER BY dia;

-- 9c · La serie para el gráfico: septiembre (historia) + octubre con las anomalías marcadas
SELECT s.ts_utc,
  DATETIME(s.ts_utc, 'America/Santiago') AS ts_chile,
  s.clientes_afectados,
  a.is_anomaly,                 -- NULL en septiembre (es la historia)
  CAST(a.upper_bound AS INT64) AS limite_superior
FROM fuentes.sec_rm_horario AS s
LEFT JOIN trabajo.anomalias_luz AS a ON a.time_series_timestamp = s.ts_utc
ORDER BY s.ts_utc;
