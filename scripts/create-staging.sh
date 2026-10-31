#!/bin/bash
# Cria o ambiente de homologação (projeto Firebase separado), sem WhatsApp nem Mercado Pago:
# as mensagens só aparecem nos logs. Rodar uma vez, com a conta Owner.
#
#   bash scripts/create-staging.sh [id-do-projeto]
#
# Depois: barber-back → firebase deploy --only functions -P staging
#         barber-front → firebase deploy --only hosting -P staging
set -euo pipefail

STAGING=${1:-barber-home-staging}
BILLING=${BILLING:-011041-BEB844-8228CB}
DIR=$(cd "$(dirname "$0")/.." && pwd)

gcloud projects describe "$STAGING" >/dev/null 2>&1 || gcloud projects create "$STAGING" --name="Barber Home (homologacao)"
gcloud billing projects link "$STAGING" --billing-account="$BILLING" >/dev/null
firebase projects:addfirebase "$STAGING" >/dev/null 2>&1 || true

gcloud services enable firestore.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com run.googleapis.com cloudscheduler.googleapis.com secretmanager.googleapis.com \
  eventarc.googleapis.com iamcredentials.googleapis.com identitytoolkit.googleapis.com --project "$STAGING"

gcloud firestore databases describe --database="(default)" --project "$STAGING" >/dev/null 2>&1 ||
  gcloud firestore databases create --location=southamerica-east1 --type=firestore-native --project "$STAGING"
gcloud storage buckets describe "gs://$STAGING-media" >/dev/null 2>&1 ||
  gcloud storage buckets create "gs://$STAGING-media" --project "$STAGING" --location=southamerica-east1 \
    --uniform-bucket-level-access --public-access-prevention

# Firebase Auth inicializado (login do link mágico e do Google).
TOKEN=$(gcloud auth print-access-token)
curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: $STAGING" -H "Content-Type: application/json" \
  "https://identitytoolkit.googleapis.com/v2/projects/$STAGING/identityPlatform:initializeAuth" -d '{}' >/dev/null || true

PROJECT="$STAGING" bash "$DIR/scripts/bootstrap-secrets.sh"
(cd "$DIR/firebase" && firebase deploy --only firestore --project "$STAGING")

APP_ID=$(firebase apps:list WEB --project "$STAGING" 2>/dev/null | grep -oE '1:[0-9]+:web:[0-9a-f]+' | head -1)
[ -n "$APP_ID" ] || APP_ID=$(firebase apps:create WEB barber-front --project "$STAGING" | grep -oE '1:[0-9]+:web:[0-9a-f]+' | head -1)
CONFIG=$(firebase apps:sdkconfig WEB "$APP_ID" --project "$STAGING")
API_KEY=$(echo "$CONFIG" | sed -nE 's/.*"apiKey": "([^"]+)".*/\1/p')
SENDER=$(echo "$CONFIG" | sed -nE 's/.*"messagingSenderId": "([^"]+)".*/\1/p')

cat > "$DIR/../barber-front/.env.$STAGING" <<ENV
VITE_FIREBASE_API_KEY=$API_KEY
VITE_FIREBASE_AUTH_DOMAIN=$STAGING.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=$STAGING
VITE_FIREBASE_APP_ID=$APP_ID
VITE_FIREBASE_SENDER_ID=$SENDER
ENV

cat > "$DIR/../barber-back/.env.$STAGING" <<ENV
PUBLIC_URL=https://$STAGING.web.app
MEDIA_BUCKET=$STAGING-media
EVOLUTION_URL=unset
BOT_PHONE=unset
ADMIN_PHONE=unset
BOT_ALLOWLIST=unset
ENV

echo "Homologação pronta: https://$STAGING.web.app (publique as Functions e o Hosting com -P staging)."
