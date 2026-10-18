-- 04 · AI.AGG: resumir muchas filas en una respuesta (GA desde el 13-oct-2026).
-- Agrega las notas sobre cortes de luz de cada evento y pide una explicación.
-- Es la misma query de la slide «AI.AGG».
SELECT evento,
  COUNT(*) AS notas,
  AI.AGG(
    CONCAT(medio, ': ', titular, '. ', bajada_o_extracto),
    '''Explica en máximo 4 viñetas, en español, por qué
    los medios dan cifras distintas de clientes sin luz.
    Cita el medio de cada cifra.'''
  ) AS explicacion
FROM fuentes.noticias
WHERE REGEXP_CONTAINS(
  LOWER(CONCAT(titular, ' ', bajada_o_extracto)),
  r'luz|eléctric|clientes')
GROUP BY evento
ORDER BY notas DESC;
