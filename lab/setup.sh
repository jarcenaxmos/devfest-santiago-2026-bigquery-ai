#!/bin/bash
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: MIT
#
# Language: Bash / Shell
# Description: Copia los datos del workshop DevFest Santiago 2026 (BigQuery AI)
#   al proyecto del asistente, en us-east1: imágenes satelitales a un bucket
#   propio, las tablas de devfest-demo-bq.fuentes a un dataset `fuentes` (lo
#   que se entrega) y un dataset `trabajo` vacío (lo que se crea en el lab).
#
# Uso (en Cloud Shell, con el proyecto del asistente seleccionado):
#   bash lab/setup.sh [--project ID] [--bucket NOMBRE]
#                     [--fuentes NOMBRE] [--trabajo NOMBRE]
#
# Opciones:
#   --project ID       Proyecto destino (por defecto, el de gcloud config).
#   --bucket NOMBRE    Bucket destino (por defecto <proyecto>-devfest).
#   --fuentes NOMBRE   Dataset con los datos entregados (por defecto fuentes).
#   --trabajo NOMBRE   Dataset vacío para el lab (por defecto trabajo).
#   -h, --help         Muestra esta ayuda.
#
# Se puede volver a ejecutar: las fuentes se reemplazan; `trabajo` se crea
# solo si no existe (no se borra lo que el asistente ya hizo).

set -euo pipefail
IFS=$'\n\t'

readonly ORIGEN_PROYECTO="devfest-demo-bq"
readonly ORIGEN_DATASET="fuentes"
readonly ORIGEN_BUCKET="gs://devfest-demo-bq-lab"
readonly REGION="us-east1"
# En el origen las dos series SEC ya están materializadas como tablas con sus
# descripciones de columna (las usa el data agent): basta con copiarlas.
readonly TABLAS=(noticias satelite_horario sec_clientes_sin_luz
  sec_rm_horario sec_rm_comuna_horario lluvia_dmc_diaria estaciones_dmc)
readonly APIS=(bigquery.googleapis.com aiplatform.googleapis.com
  geminidataanalytics.googleapis.com cloudaicompanion.googleapis.com
  storage.googleapis.com)
readonly DESC_FUENTES="Fuentes del workshop DevFest Santiago 2026 (BigQuery AI): datos que se entregan listos y no se modifican. Prensa (noticias), lluvia diaria DMC y estaciones, clientes sin luz SEC por hora y comuna, y lo que Gemini vio cada hora en el satélite GOES-19. Región Metropolitana, 1-sep a 14-oct-2026 (lluvia desde 2016)."
readonly DESC_TRABAJO="Trabajo del workshop DevFest Santiago 2026: aquí quedan las tablas que crea cada asistente durante el lab (resultados de AI.CLASSIFY, AI.GENERATE, AI.FORECAST, AI.DETECT_ANOMALIES). Empieza vacío; se puede borrar sin perder las fuentes."

log_info()  { echo "[INFO]  $(date -Iseconds) $*"; }
log_error() { echo "[ERROR] $(date -Iseconds) $*" >&2; }

usage() { sed -n '20,30p' "$0" | sed 's/^# \{0,1\}//'; }

proyecto=""
bucket=""
fuentes="fuentes"
trabajo="trabajo"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) proyecto="$2"; shift 2 ;;
    --bucket) bucket="$2"; shift 2 ;;
    --fuentes) fuentes="$2"; shift 2 ;;
    --trabajo) trabajo="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Opción desconocida: $1"; usage; exit 2 ;;
  esac
done

for cmd in gcloud bq; do
  command -v "$cmd" >/dev/null 2>&1 || { log_error "Falta $cmd"; exit 1; }
done
proyecto="${proyecto:-$(gcloud config get-value project 2>/dev/null)}"
[[ -n "$proyecto" ]] || { log_error "Sin proyecto: usa --project"; exit 2; }
bucket="gs://${bucket:-${proyecto}-devfest}"
log_info "Proyecto ${proyecto} · datasets ${fuentes} y ${trabajo} · bucket ${bucket}"

# Los datos de origen están abiertos a cualquier cuenta de Google solo durante
# octubre de 2026. Si no se pueden leer, mostrar el error real y salir.
if ! err="$(gcloud storage ls "${ORIGEN_BUCKET}/horario/ir13/" 2>&1 >/dev/null)"; then
  log_error "No puedo leer los datos de origen (${ORIGEN_BUCKET}):"
  log_error "${err%%$'\n'*}"
  log_error "Si es un problema de sesión, ejecuta: gcloud auth login"
  log_error "Los datos están abiertos solo durante octubre de 2026. Dudas: javier@axmos.tech"
  exit 1
fi

log_info "1/5 Habilitando APIs (puede tardar ~1 min)"
gcloud services enable "${APIS[@]}" --project="$proyecto"

log_info "2/5 Bucket ${bucket} en ${REGION}"
if ! gcloud storage buckets describe "$bucket" >/dev/null 2>&1; then
  gcloud storage buckets create "$bucket" --project="$proyecto" \
    --location="$REGION" --uniform-bucket-level-access
fi

log_info "3/5 Copiando imágenes satelitales (~35 MB)"
gcloud storage cp -r "${ORIGEN_BUCKET}/horario/ir13" "${bucket}/horario/" \
  --no-clobber --no-user-output-enabled
gcloud storage cp -r "${ORIGEN_BUCKET}/geocolor_santiago" "${bucket}/" \
  --no-clobber --no-user-output-enabled

log_info "4/5 Datasets ${fuentes} (copia) y ${trabajo} (vacío)"
crear_dataset() {
  local destino="${proyecto}:$1"
  if ! bq show --dataset "$destino" >/dev/null 2>&1; then
    bq --location="$REGION" mk --dataset --description "$2" "$destino" \
      >/dev/null
  fi
}
crear_dataset "$fuentes" "$DESC_FUENTES"
crear_dataset "$trabajo" "$DESC_TRABAJO"
for t in "${TABLAS[@]}"; do
  bq --project_id="$proyecto" cp -f \
    "${ORIGEN_PROYECTO}:${ORIGEN_DATASET}.${t}" "${proyecto}:${fuentes}.${t}" \
    >/dev/null
  log_info "  ${fuentes}.${t}"
done
# satelite_horario guarda la URI de cada imagen: que apunte al bucket propio.
bq query --project_id="$proyecto" --location="$REGION" \
  --use_legacy_sql=false --quiet \
  "UPDATE \`${proyecto}.${fuentes}.satelite_horario\`
   SET uri = REPLACE(uri, '${ORIGEN_BUCKET}/', '${bucket}/') WHERE TRUE" \
  >/dev/null

log_info "5/5 Verificación"
bq query --project_id="$proyecto" --location="$REGION" \
  --use_legacy_sql=false --format=pretty \
  "SELECT
     (SELECT COUNT(*) FROM \`${proyecto}.${fuentes}.noticias\`) AS noticias,
     (SELECT MAX(clientes_afectados)
        FROM \`${proyecto}.${fuentes}.sec_rm_horario\`) AS peak_sec,
     (SELECT COUNT(*) FROM \`${proyecto}.${fuentes}.satelite_horario\`)
       AS horas_satelite,
     (SELECT COUNT(*) FROM \`${proyecto}.${fuentes}.lluvia_dmc_diaria\`)
       AS dias_lluvia,
     (SELECT COUNT(*) FROM \`${proyecto}.${trabajo}.INFORMATION_SCHEMA.TABLES\`)
       AS tablas_trabajo"
n_img="$(gcloud storage ls "${bucket}/horario/ir13/" | wc -l | tr -d ' ')"
log_info "Imágenes IR en ${bucket}: ${n_img} (esperado 1034)"
log_info "Listo. Esperado: noticias 120 · peak_sec 40366 · horas 1034 · dias_lluvia 72589 · tablas_trabajo 0 (o las que ya creaste)."
