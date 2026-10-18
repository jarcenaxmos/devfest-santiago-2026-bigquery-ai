-- 06 · ¿Qué modelo respondió? (la información del job no lo dice)
-- AI.GENERATE devuelve full_response: el JSON completo de Vertex AI. Su campo
-- model_version dice qué Gemini contestó cada fila. Sin endpoint, BigQuery elige
-- "una versión estable reciente" (hoy gemini-3.5-flash-lite, según la doc).
-- AI.CLASSIFY / AI.IF / AI.SCORE no exponen full_response: esto sirve con AI.GENERATE.

SELECT FORMAT_DATETIME('%H:%M', ts_chile) AS hora_chile,
  JSON_VALUE(full_response, '$.model_version') AS modelo,
  JSON_VALUE(full_response, '$.usage_metadata.total_token_count') AS tokens
FROM trabajo.satelite_13oct
ORDER BY ts_chile;
