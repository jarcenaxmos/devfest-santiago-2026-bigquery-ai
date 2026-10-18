-- 01 · Prueba de humo: ¿mi proyecto llega a Gemini desde BigQuery?
-- Lee 3 titulares de fuentes.noticias y los clasifica. Si ves 3 filas con
-- "impacto" lleno, tu proyecto, tus permisos y la API de Vertex AI están OK.
SELECT titular,
  AI.CLASSIFY(titular,
    categories => ['vivienda', 'energia', 'transporte', 'educacion', 'agua']) AS impacto
FROM fuentes.noticias
ORDER BY url
LIMIT 3;
