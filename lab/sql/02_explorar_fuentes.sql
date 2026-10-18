-- 02 · Explorar las fuentes antes de usarlas (sin AI, costo ~0).
-- Dos datasets: `fuentes` = lo que se entrega (solo lectura) y
-- `trabajo` = donde guardamos lo que creamos en el lab (empieza vacío).
-- Ejecuta cada bloque por separado (selecciona el bloque y "Ejecutar").

-- 2a · ¿Qué hay en cada dataset? (metadatos, gratis; `trabajo` aún está vacío)
SELECT dataset_id AS dataset, table_id AS tabla, row_count AS filas
FROM fuentes.__TABLES__
UNION ALL
SELECT dataset_id, table_id, row_count
FROM trabajo.__TABLES__
ORDER BY dataset, tabla;

-- 2b · Prensa: 120 notas, ¿de qué evento y de qué medio?
SELECT evento, COUNT(*) AS notas, COUNT(DISTINCT medio) AS medios,
  MIN(fecha_publicacion) AS desde, MAX(fecha_publicacion) AS hasta
FROM fuentes.noticias
GROUP BY evento
ORDER BY notas DESC;

-- 2c · Lluvia DMC: un día por estación. Octubre en Quinta Normal (330020), año a año.
SELECT EXTRACT(YEAR FROM fecha) AS anio,
  ROUND(SUM(mm_dia), 1) AS mm_octubre,
  COUNT(*) AS dias_con_dato
FROM fuentes.lluvia_dmc_diaria
WHERE codigo_estacion = '330020'
  AND EXTRACT(MONTH FROM fecha) = 10
  AND NOT IFNULL(dato_sospechoso, FALSE)
GROUP BY anio
ORDER BY anio;

-- 2d · Cortes de luz SEC: total RM por hora. Los 5 peores momentos.
SELECT ts_chile, clientes_afectados, comunas_afectadas
FROM fuentes.sec_rm_horario
ORDER BY clientes_afectados DESC
LIMIT 5;

-- 2e · Satélite: lo que Gemini ya vio en cada hora (1.034 horas, 1-sep → 14-oct).
SELECT ts_chile, intensidad, nubosidad_pct, conveccion, celula_sobre_santiago, tipo, uri
FROM fuentes.satelite_horario
WHERE ts_chile BETWEEN DATETIME '2026-10-13 13:00:00' AND DATETIME '2026-10-13 17:00:00'
ORDER BY ts_chile;
