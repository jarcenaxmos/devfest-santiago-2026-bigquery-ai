# Gemini + TimesFM en BigQuery: ¿quién vio venir la tormenta?

Workshop del **DevFest Cloud Santiago 2026** (17 de octubre, Inacap Apoquindo). Usamos solo SQL en BigQuery para analizar el octubre más lluvioso de Santiago: titulares de prensa, imágenes de satélite y los cortes de luz de la SEC.

> El video de la demo está en [`media/santiago-13oct-app.mp4`](media/santiago-13oct-app.mp4): el satélite mostró la tormenta sobre Santiago una hora antes de que saltaran los cortes de luz.

## Qué vas a aprender

1. Usar **AI.CLASSIFY, AI.SCORE, AI.IF y AI.AGG** sobre noticias, dentro de un `SELECT`.
2. Hacer que **Gemini mire imágenes de satélite** con `AI.GENERATE`.
3. **Pronosticar** con TimesFM 3.0 (`AI.FORECAST`) y **detectar anomalías** (`AI.DETECT_ANOMALIES`).
4. Descubrir qué pasa cuando un pronóstico no ve venir lo que nunca había ocurrido.

No necesitas instalar nada: todo se hace en el navegador.

## Empieza aquí

**[GUIA.md](GUIA.md)**: paso a paso, con los comandos para copiar y pegar. Toma unos 15 minutos de preparación y después ejecutas las consultas una por una.

## Qué hay en este repo

| Carpeta | Qué contiene |
|---|---|
| [`GUIA.md`](GUIA.md) | La guía para hacer el workshop por tu cuenta |
| [`lab/setup.sh`](lab/setup.sh) | Prepara tu proyecto de Google Cloud con los datos (un solo comando) |
| [`lab/sql/`](lab/sql) | Las 10 consultas SQL del workshop, numeradas en orden |
| [`slides/`](slides) | Las láminas en PDF |
| [`app/timelapse/`](app/timelapse) | La app web de la demo (opcional, para quien ya conozca Cloud Run) |

## Qué necesitas

- Una cuenta de Google.
- Un proyecto de Google Cloud con facturación activa. El lab es barato, pero no es gratis.

> **Aviso sobre los datos.** Los datos viven en un proyecto de Javier (`devfest-demo-bq`) y el setup los copia al tuyo. Para que cualquier persona pueda hacerlo, esa lectura está abierta a cualquier cuenta de Google **solo durante octubre de 2026**. En noviembre el setup ya no podrá copiarlos. Si lo necesitas después, escribe a [javier@axmos.tech](mailto:javier@axmos.tech).

## Autor

Javier Arce Navea · Cloud Data & AI Engineer en Axmos Technologies · [LinkedIn](https://www.linkedin.com/in/jarcen) · [javier@axmos.tech](mailto:javier@axmos.tech)

Licencia: [MIT](LICENSE).
