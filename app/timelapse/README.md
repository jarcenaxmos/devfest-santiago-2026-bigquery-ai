# devfest-timelapse: Santiago desde el espacio

App web de una sola página para la demo del workshop. Muestra el timelapse satelital GOES-19 del 13 de octubre de 2026 y, sincronizado cuadro a cuadro, lo que leyó Gemini en la imagen de cada hora y la curva de clientes sin luz de la SEC.

**Es opcional.** Para hacer el workshop no la necesitas: está pensada para quien ya conoce Cloud Run y quiere ver cómo se armó la demo. El video del resultado está en [`../../media/santiago-13oct-app.mp4`](../../media/santiago-13oct-app.mp4).

## Qué hace

- Reproduce 48 cuadros del 13-oct (y 36 del 8-oct) con play/pausa, slider y velocidad.
- Muestra la tarjeta "Lo que vio Gemini" y el gráfico de clientes sin luz sincronizados con el cuadro.
- Los datos están precalculados en [`data/eventos.json`](data/eventos.json): en vivo no consulta BigQuery.

Controles: <kbd>espacio</kbd> reproduce o pausa, <kbd>←</kbd> <kbd>→</kbd> avanzan un cuadro, <kbd>1</kbd> y <kbd>2</kbd> cambian entre el 13-oct y el 8-oct. Un clic en el gráfico salta a esa hora.

## Cómo está armada

```
Navegador ──> Cloud Run (FastAPI, Python 3.12)
                 ├─ al iniciar: descarga los cuadros JPG de un bucket a memoria (~30 MB)
                 ├─ data/eventos.json (dentro de la imagen): Gemini horario + SEC horario + hitos
                 └─ valida el token de IAP en cada request (salvo /health, /ready y /metrics)
```

- Frontend en HTML, CSS y JS puros, sin CDNs. La tipografía Nunito Sans va incluida (licencia OFL).
- Endpoints: `GET /`, `GET /api/datos?evento=13oct|08oct`, `GET /api/eventos`, `GET /api/cuadro/...`, `GET /health`, `GET /ready` y `GET /metrics`.
- Los logs son JSON a stdout.

## Probarla en tu computador

Necesitas Python 3.12 o superior y `gcloud`.

```bash
cd app/timelapse
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
gcloud auth application-default login
IAP_REQUERIDO=false .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Abre <http://localhost:8080/?hora=16:00>. `IAP_REQUERIDO=false` solo desactiva la validación de IAP, que en tu computador no existe.

Los cuadros se leen del bucket `gs://devfest-demo-bq-lab/wow/`, que está abierto a cualquier cuenta de Google **solo durante octubre de 2026**. Después tendrás que generar tus propios cuadros con [`scripts/generar_cuadros.py`](scripts/generar_cuadros.py) y apuntar la variable `BUCKET` a tu bucket.

## Desplegarla en Cloud Run con IAP (avanzado)

Cambia `TU_PROYECTO` y `TU_NUMERO_DE_PROYECTO` (se ve en la página de inicio de la consola). Se necesita `gcloud` con los componentes `beta`.

```bash
P=TU_PROYECTO
N=TU_NUMERO_DE_PROYECTO
SA=sa-devfest-timelapse@$P.iam.gserviceaccount.com
IMG=us-east1-docker.pkg.dev/$P/devfest-timelapse/app:v1

gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com \
  iap.googleapis.com iam.googleapis.com --project=$P
gcloud iam service-accounts create sa-devfest-timelapse --project=$P
gcloud artifacts repositories create devfest-timelapse --repository-format=docker \
  --location=us-east1 --project=$P

# Esta cuenta de servicio necesita leer el bucket con los cuadros
gcloud storage buckets add-iam-policy-binding gs://TU_BUCKET \
  --member=serviceAccount:$SA --role=roles/storage.objectViewer --project=$P

gcloud builds submit --region=us-east1 --tag $IMG --project=$P .

gcloud beta run deploy devfest-timelapse --project=$P --region=us-east1 --image=$IMG \
  --service-account=$SA --no-allow-unauthenticated --iap \
  --memory=1Gi --cpu=1 --min-instances=0 --max-instances=2 \
  --set-env-vars="IAP_AUDIENCIA=/projects/$N/locations/us-east1/services/devfest-timelapse,BUCKET=TU_BUCKET" \
  --startup-probe=httpGet.path=/ready,periodSeconds=2,failureThreshold=30,timeoutSeconds=2
```

Después, da acceso a quien quieras con el rol `roles/iap.httpsResourceAccessor`:

```bash
gcloud beta iap web add-iam-policy-binding --project=$P --region=us-east1 \
  --resource-type=cloud-run --service=devfest-timelapse \
  --member=user:PERSONA@ejemplo.com --role=roles/iap.httpsResourceAccessor --condition=None
```

- Nunca uses `allUsers` ni `allAuthenticatedUsers` en este servicio.
- Las personas de fuera de tu organización requieren además un cliente OAuth propio. Ver la [documentación de IAP en Cloud Run](https://docs.cloud.google.com/run/docs/securing/identity-aware-proxy-cloud-run).
- **Costo:** con `--min-instances=0` es prácticamente cero para un uso ocasional.

## Variables de entorno

| Variable | Uso |
|---|---|
| `IAP_AUDIENCIA` | Audiencia esperada del token de IAP. Obligatoria, salvo con `IAP_REQUERIDO=false` |
| `IAP_REQUERIDO` | `false` solo para desarrollo local |
| `BUCKET` | Bucket con los cuadros |
| `DATOS` | Ruta alternativa a `eventos.json` |

No hay secretos en el código.

## Licencia

MIT. Ver [`../../LICENSE`](../../LICENSE).
