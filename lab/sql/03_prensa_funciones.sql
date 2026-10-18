-- 03 · Prensa: AI.CLASSIFY, AI.SCORE y AI.IF sobre fuentes.noticias.
-- Ejecuta los bloques en orden.

-- 3a · Una sola query, tres funciones (la de la slide).
-- AI.IF en el WHERE le pregunta al modelo, fila por fila, y deja pasar solo
-- las filas donde responde TRUE. Es estocástico: el número de filas puede
-- variar entre ejecuciones (medido 15-oct: ver README).
SELECT titular,
  AI.CLASSIFY(titular, categories => [
    'vivienda', 'energia', 'agua', 'transporte',
    'educacion', 'salud', 'otro']) AS impacto,
  AI.SCORE(('Gravedad humana de 1 a 10: ', titular)) AS gravedad
FROM fuentes.noticias
WHERE AI.IF(('¿Critica la respuesta de las autoridades? ', titular))
ORDER BY gravedad DESC;

-- 3b · Guardar el resultado en `trabajo`: el modelo se llama una vez y
-- después consultamos una tabla normal (rápida, gratis y repetible).
CREATE OR REPLACE TABLE trabajo.noticias_enriquecidas AS
SELECT evento, medio, fecha_publicacion, titular,
  AI.CLASSIFY(titular, categories => [
    'vivienda', 'energia', 'agua', 'transporte',
    'educacion', 'salud', 'otro']) AS impacto,
  AI.SCORE(('Gravedad humana de 1 a 10: ', titular)) AS gravedad,
  AI.IF(('¿Critica la respuesta de las autoridades? ', titular)) AS critica_autoridades
FROM fuentes.noticias;

-- 3c · Ya sin AI: consultas sobre lo que guardamos.
SELECT evento, impacto, COUNT(*) AS notas,
  COUNTIF(critica_autoridades) AS critican,
  ROUND(AVG(gravedad), 1) AS gravedad_media
FROM trabajo.noticias_enriquecidas
GROUP BY evento, impacto
ORDER BY evento, notas DESC;
