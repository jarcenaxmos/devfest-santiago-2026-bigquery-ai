# Guía paso a paso

Haz los pasos en orden. Cada bloque con comandos se copia y se pega tal cual. Si algo falla, mira [Si algo sale mal](#si-algo-sale-mal) al final.

**Tiempo:** ~15 min de preparación + ~45 min de consultas.

---

## Parte 1 · Preparación

### Paso 1. Ten un proyecto de Google Cloud con facturación

1. Entra a [console.cloud.google.com](https://console.cloud.google.com) con tu cuenta de Google.
2. Crea un **proyecto nuevo** (menú de arriba → *Proyecto nuevo*). Anota su nombre (ID).
3. Comprueba que tiene una **cuenta de facturación** vinculada: menú ☰ → *Facturación*. Sin esto, Gemini y TimesFM no funcionan.

> ¿Créditos de la comunidad? Si te dieron un código o un QR de créditos, canjéalos **antes** de crear el proyecto y vincula el proyecto a la cuenta de facturación que aparece (se llama algo como "GDP Credit…" y puede tardar hasta 5 minutos).

### Paso 2. Abre Cloud Shell

Cloud Shell es una terminal que Google te da gratis en el navegador, ya con `gcloud` y `bq` instalados.

1. En la consola, arriba a la derecha, haz clic en el ícono **`>_`** (*Activar Cloud Shell*).
2. Espera a que aparezca el prompt. Si te pide autorizar, acepta.
3. Asegúrate de estar en tu proyecto (cambia `TU_PROYECTO` por el ID del paso 1):

```bash
gcloud config set project TU_PROYECTO
```

### Paso 3. Descarga el repo y ejecuta el setup

```bash
git clone https://github.com/jarcenaxmos/devfest-santiago-2026-bigquery-ai.git
cd devfest-santiago-2026-bigquery-ai
bash lab/setup.sh
```

Toma ~2 minutos. Este comando:

- activa las APIs necesarias (BigQuery, Gemini y Cloud Storage),
- crea un bucket con las imágenes de satélite,
- copia 7 tablas de datos a un dataset llamado `fuentes`,
- crea un dataset vacío llamado `trabajo`, donde guardarás lo que hagas.

Al final debes ver esta línea de verificación:

| noticias | peak_sec | horas_satelite | dias_lluvia | tablas_trabajo |
|---|---|---|---|---|
| 120 | 40366 | 1034 | 72589 | 0 |

Si los números coinciden, estás listo. Todo quedó en la región `us-east1`.

---

## Parte 2 · Las consultas

### Cómo ejecutar una consulta

1. En la consola, abre **BigQuery** (búscalo arriba).
2. Haz clic en **+** (*Crear consulta SQL nueva*).
3. Abre el archivo de la tabla de abajo en GitHub (carpeta [`lab/sql/`](lab/sql)), copia el contenido y pégalo en BigQuery.
4. Haz clic en **Ejecutar**.

Las consultas no llevan el nombre del proyecto: leen de `fuentes` y escriben en `trabajo`, así que funcionan en el tuyo sin cambiar nada.

> Algunos archivos tienen varios bloques (`-- 2a`, `-- 2b`…). Ejecútalos **uno por uno**: selecciona el bloque y haz clic en *Ejecutar*. Los archivos 05 y 10 son scripts: se ejecutan completos.

### Las 10 consultas, en orden

| # | Archivo | Qué hace | Qué deberías ver |
|---|---|---|---|
| 1 | [`01_prueba_humo.sql`](lab/sql/01_prueba_humo.sql) | Clasifica 3 titulares con Gemini | 3 filas con la columna `impacto` llena |
| 2 | [`02_explorar_fuentes.sql`](lab/sql/02_explorar_fuentes.sql) | Mira qué hay en cada tabla (sin IA) | Quinta Normal: 108 mm en octubre 2026; peak de cortes de luz: 40.366 |
| 3 | [`03_prensa_funciones.sql`](lab/sql/03_prensa_funciones.sql) | AI.CLASSIFY + AI.SCORE + AI.IF sobre 120 noticias | ~15 notas que critican a las autoridades |
| 4 | [`04_prensa_agg.sql`](lab/sql/04_prensa_agg.sql) | AI.AGG: un resumen por grupo de noticias | 3 grupos (tormenta, frontal, otro) |
| 5 | [`05_satelite_gemini.sql`](lab/sql/05_satelite_gemini.sql) | Gemini mira 8 imágenes de satélite del 13-oct | La intensidad sube hasta 8 a las 16:00 |
| 6 | [`06_modelo_usado.sql`](lab/sql/06_modelo_usado.sql) | Averigua qué modelo respondió | `gemini-3.5-flash-lite` |
| 7 | [`07_cambiar_modelo.sql`](lab/sql/07_cambiar_modelo.sql) | Compara dos modelos con la misma imagen | Dos modelos, dos lecturas |
| 8 | [`08_timesfm_ciego.sql`](lab/sql/08_timesfm_ciego.sql) | TimesFM 3.0 pronostica los cortes de luz | Pronostica ~2.300 a las 17:00; en la realidad fueron 40.366 |
| 9 | [`09_anomalias.sql`](lab/sql/09_anomalias.sql) | Detecta horas anómalas en octubre | 71 de 328 horas marcadas |
| 10 | [`10_interpretar_pronostico.sql`](lab/sql/10_interpretar_pronostico.sql) | Pronóstico "ciego" vs. "con ojos" (satélite) | El valor real cae fuera de ambas bandas |

Los resultados de la IA pueden variar un poco entre ejecuciones: es normal.

**Si vas con prisa:** las consultas 6, 7 y 10 son las más prescindibles.

---

## Si algo sale mal

| Qué ves | Qué hacer |
|---|---|
| El setup dice `No puedo leer los datos de origen` o `403` | Los datos solo están abiertos durante octubre de 2026. Si es octubre, abre un [issue](../../issues) con el mensaje de error. Si ya pasó, escribe a [javier@axmos.tech](mailto:javier@axmos.tech). |
| El setup dice `billing` o que no puede activar APIs | Tu proyecto no tiene facturación vinculada. Repite el Paso 1. |
| `Cannot find project` o el proyecto sale vacío | Repite `gcloud config set project TU_PROYECTO` (Paso 2). |
| La consulta dice `Not found: Dataset fuentes` | El setup no terminó. Vuelve a ejecutar `bash lab/setup.sh`: se puede repetir sin problema. |
| La consulta dice `429` o `quota` | Hay demasiado uso de Gemini a la vez. Espera 1 minuto y vuelve a ejecutar. |
| La consulta 5 falla | Plan B: los mismos resultados ya están calculados en `fuentes.satelite_horario`. |
| `must be a string literal` | No muevas el `output_schema` a una variable: tiene que ir escrito directo en la consulta. |

## Cuando termines

Para no pagar por lo que dejaste, borra los datos de tu proyecto (en Cloud Shell, cambiando `TU_PROYECTO` por el ID del tuyo):

```bash
bq --project_id=TU_PROYECTO rm -r -f -d fuentes
bq --project_id=TU_PROYECTO rm -r -f -d trabajo
gcloud storage rm -r gs://TU_PROYECTO-devfest
```

O borra el proyecto completo desde *IAM y administración → Configuración → Cerrar*.

> **Costos:** no los medimos por persona. Las consultas con Gemini y TimesFM cobran por uso. Si te preocupa, crea una *alerta de presupuesto* en Facturación antes de empezar.
