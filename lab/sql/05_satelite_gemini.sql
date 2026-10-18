-- 05 · Satélite (paso 5 de la guía): Gemini mira 8 imágenes infrarrojas del 13-oct (12:00 a 19:00 hora Chile).
-- Las imágenes están en tu bucket; fuentes.satelite_horario guarda la URI de cada hora
-- y OBJ.MAKE_REF(uri) la convierte en un ObjectRef que AI.GENERATE puede "ver".
-- Script: ejecútalo completo (DECLARE + CREATE + SELECT). Modelo por defecto
-- (gemini-3.5-flash-lite); ~20 s. Si falla, plan B: los mismos campos ya están en
-- fuentes.satelite_horario (1.034 horas procesadas con gemini-3.8-flash).

DECLARE prompt STRING DEFAULT '''
Eres meteorólogo satelital. Analiza imágenes infrarrojas GOES-19 banda 13 (10,3 µm) con paleta realzada de NASA GIBS.
Recorte de ~220 km (N-S) x 185 km (E-O), norte arriba. SANTIAGO DE CHILE ESTÁ EXACTAMENTE EN EL CENTRO de la imagen.
Borde izquierdo = costa del Pacífico; tercio derecho = cordillera de los Andes. No hay líneas de costa ni fronteras dibujadas.
El IR mide temperatura de tope de nube: se ve IGUAL de día y de noche (no juzgues por luz ni sombras).
Paleta (temperatura del tope):
- gris oscuro = suelo o mar despejado y cálido; gris claro = nube baja/niebla o suelo frío (sin importancia convectiva)
- cian/celeste ≈ -20 °C; azul ≈ -25 a -30 °C (nube media)
- verde oscuro a verde brillante ≈ -35 a -45 °C (nube alta, frontal o yunque)
- amarillo ≈ -50 °C; naranja/rojo ≤ -55 °C (topes de cumulonimbo: convección profunda)
Escala de intensidad (usa la zona de ~50 km alrededor del centro):
0 = todo gris (despejado o solo nube baja); 1-2 = parches cian/azul dispersos; 3-4 = nube media/alta extensa (azul/verde oscuro) sin topes < -40 °C;
5-6 = banda frontal/estratiforme profunda con verde extenso y homogéneo; 7-8 = núcleos compactos amarillos/naranjas (convección) cerca del centro;
9-10 = núcleos naranjas/rojos grandes o múltiples sobre el centro.
"conveccion" = hay núcleos compactos amarillo/naranja/rojo en cualquier parte del recorte. "celula_sobre_santiago" = uno de esos núcleos cubre el centro.
''';

CREATE OR REPLACE TABLE trabajo.satelite_13oct AS
SELECT s.ts_chile, s.uri,
  ai.intensidad, ai.nubosidad_pct, ai.conveccion, ai.celula_sobre_santiago,
  ai.tipo, ai.descripcion,
  ai.full_response,  -- respuesta completa del modelo (la usamos en 06)
  ai.status          -- vacío = OK
FROM fuentes.satelite_horario AS s,
UNNEST([STRUCT(AI.GENERATE(
  (prompt, OBJ.MAKE_REF(s.uri)),
  -- output_schema tiene que ser un literal (no acepta variables: verificado 15-oct)
  output_schema => '''intensidad INT64, nubosidad_pct INT64, conveccion BOOL,
    celula_sobre_santiago BOOL, descripcion STRING,
    tipo STRING OPTIONS(description="despejado|nubosidad_baja|estratiforme|frontal|convectiva|mixta")'''
) AS ai)])
WHERE s.ts_chile BETWEEN DATETIME '2026-10-13 12:00:00' AND DATETIME '2026-10-13 19:00:00';

SELECT FORMAT_DATETIME('%H:%M', ts_chile) AS hora_chile,
  intensidad, nubosidad_pct, conveccion, celula_sobre_santiago, tipo, descripcion
FROM trabajo.satelite_13oct
ORDER BY ts_chile;
