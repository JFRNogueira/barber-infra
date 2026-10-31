#!/bin/bash
# Cria os segredos do projeto no Secret Manager (rodar uma vez, com sua conta Owner).
# Segredos que já existem não são alterados. Valores gerados aqui nunca são impressos.
#
#   bash scripts/bootstrap-secrets.sh
#
# Para trocar um valor depois (ex.: credenciais do Mercado Pago):
#   printf '%s' 'VALOR' | gcloud secrets versions add MP_ACCESS_TOKEN --data-file=- --project barber-app-259c1
set -euo pipefail

PROJECT=${PROJECT:-barber-app-259c1}

create() {
  if gcloud secrets describe "$1" --project "$PROJECT" >/dev/null 2>&1; then
    echo "já existe: $1"
  else
    printf '%s' "$2" | tr -d '\r\n' | gcloud secrets create "$1" --data-file=- --replication-policy=automatic --project "$PROJECT" >/dev/null
    echo "criado:    $1"
  fi
}

create APP_SECRET "$(openssl rand -base64 48 | tr -d '\n')"
create EVOLUTION_API_KEY "$(openssl rand -hex 32)"
create EVOLUTION_WEBHOOK_TOKEN "$(openssl rand -hex 32)"

# Mercado Pago: "unset" até a aplicação marketplace ser criada. O back-end trata
# "unset" como não configurado (o Pix não é gerado e o Johannes é avisado).
create MP_ACCESS_TOKEN unset
create MP_CLIENT_SECRET unset
create MP_WEBHOOK_SECRET unset

# E-mail (cópia dos avisos para quem tem e-mail na conta): smtps://usuario:senha@servidor:465.
create SMTP_URL unset
# API oficial do WhatsApp (Meta): "unset" enquanto a Evolution for o canal (WHATSAPP_PROVIDER vazio).
create WHATSAPP_CLOUD_TOKEN unset
create WHATSAPP_APP_SECRET unset

# Chave da Geocoding API, restrita a esse serviço (uso só no servidor).
if ! gcloud secrets describe GEOCODING_API_KEY --project "$PROJECT" >/dev/null 2>&1; then
  KEY_NAME=$(gcloud services api-keys create \
    --display-name="barber geocoding (server)" \
    --api-target=service=geocoding-backend.googleapis.com \
    --project "$PROJECT" --format="value(response.name)" 2>/dev/null)
  KEY=$(gcloud services api-keys get-key-string "$KEY_NAME" --format="value(keyString)")
  create GEOCODING_API_KEY "$KEY"
else
  echo "já existe: GEOCODING_API_KEY"
fi

# As Functions geram tokens personalizados do Firebase Auth (login do barbeiro):
# a conta de serviço delas precisa assinar com a própria identidade.
NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")
SA="$NUMBER-compute@developer.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --member="serviceAccount:$SA" --role=roles/iam.serviceAccountTokenCreator \
  --project "$PROJECT" >/dev/null
echo "ok:        $SA pode assinar tokens do Firebase Auth"
