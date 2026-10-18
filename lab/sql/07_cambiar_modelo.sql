-- 07 · Cambiar de modelo = un argumento: endpoint => '...'
-- Misma imagen (13-oct 16:00 hora Chile), dos modelos. Sin endpoint usa el modelo
-- por defecto (gemini-3.5-flash-lite: rápido y barato); con endpoint eliges otro.
SELECT
  JSON_VALUE(rapido.full_response, '$.model_version') AS modelo_1,
  rapido.result AS respuesta_1,
  JSON_VALUE(preciso.full_response, '$.model_version') AS modelo_2,
  preciso.result AS respuesta_2
FROM (
  SELECT
    AI.GENERATE(('Describe en una frase qué se ve sobre Santiago: ', OBJ.MAKE_REF(uri))) AS rapido,
    AI.GENERATE(('Describe en una frase qué se ve sobre Santiago: ', OBJ.MAKE_REF(uri)),
                endpoint => 'gemini-3.8-flash') AS preciso
  FROM fuentes.satelite_horario
  WHERE ts_chile = DATETIME '2026-10-13 16:00:00'
);
