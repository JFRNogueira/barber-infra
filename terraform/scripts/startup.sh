#!/bin/bash
# Roda a cada boot da VM; é idempotente.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
MD="http://metadata.google.internal/computeMetadata/v1"

# 2 GB de swap: a e2-micro tem só 1 GB de memória.
if ! swapon --show | grep -q /swapfile; then
  [ -f /swapfile ] || { fallocate -l 2G /swapfile; chmod 600 /swapfile; mkswap /swapfile; }
  swapon /swapfile
  grep -q /swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Docker + plugin compose pelo repositório oficial (o Ubuntu 22.04 não traz o plugin).
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

attr() { curl -fsS -H "Metadata-Flavor: Google" "$MD/instance/attributes/$1"; }
PROJECT=$(curl -fsS -H "Metadata-Flavor: Google" "$MD/project/project-id")
TOKEN=$(curl -fsS -H "Metadata-Flavor: Google" "$MD/instance/service-accounts/default/token" | sed -E 's/.*"access_token":"([^"]+)".*/\1/')
secret() {
  curl -fsS -H "Authorization: Bearer $TOKEN" \
    "https://secretmanager.googleapis.com/v1/projects/$PROJECT/secrets/$1/versions/latest:access" |
    tr -d '\n ' | sed -E 's/.*"data":"([^"]+)".*/\1/' | base64 -d
}

DOMAIN=$(attr evolution-domain)
WEBHOOK_BASE=$(attr webhook-base-url)
API_KEY=$(secret EVOLUTION_API_KEY)
WEBHOOK_TOKEN=$(secret EVOLUTION_WEBHOOK_TOKEN)

mkdir -p /opt/evolution
cd /opt/evolution
[ -f .db_password ] || { openssl rand -hex 24 > .db_password; chmod 600 .db_password; }
DB_PASSWORD=$(cat .db_password)

umask 077
cat > .env <<ENV
DOMAIN=$DOMAIN
DB_PASSWORD=$DB_PASSWORD
SERVER_URL=https://$DOMAIN
AUTHENTICATION_API_KEY=$API_KEY
WEBHOOK_GLOBAL_URL=$WEBHOOK_BASE?token=$WEBHOOK_TOKEN
ENV
umask 022

cat > Caddyfile <<'CADDY'
{$DOMAIN} {
  reverse_proxy evolution:8080
}
CADDY

cat > docker-compose.yml <<'COMPOSE'
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    command: ["postgres", "-c", "shared_buffers=32MB", "-c", "max_connections=20"]
    environment:
      POSTGRES_USER: evolution
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: evolution
    volumes:
      - postgres_data:/var/lib/postgresql/data

  evolution:
    image: evoapicloud/evolution-api:v2.3.7
    restart: unless-stopped
    depends_on: [postgres]
    environment:
      SERVER_TYPE: http
      SERVER_PORT: "8080"
      SERVER_URL: ${SERVER_URL}
      AUTHENTICATION_API_KEY: ${AUTHENTICATION_API_KEY}
      AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES: "false"
      DEL_INSTANCE: "false"
      LOG_LEVEL: ERROR,WARN
      DATABASE_PROVIDER: postgresql
      DATABASE_CONNECTION_URI: postgresql://evolution:${DB_PASSWORD}@postgres:5432/evolution?schema=public
      DATABASE_CONNECTION_CLIENT_NAME: barber
      DATABASE_SAVE_DATA_INSTANCE: "true"
      DATABASE_SAVE_DATA_NEW_MESSAGE: "false"
      DATABASE_SAVE_MESSAGE_UPDATE: "false"
      DATABASE_SAVE_DATA_CONTACTS: "false"
      DATABASE_SAVE_DATA_CHATS: "false"
      DATABASE_SAVE_DATA_LABELS: "false"
      DATABASE_SAVE_DATA_HISTORIC: "false"
      CACHE_REDIS_ENABLED: "false"
      CACHE_LOCAL_ENABLED: "true"
      WEBHOOK_GLOBAL_ENABLED: "true"
      WEBHOOK_GLOBAL_URL: ${WEBHOOK_GLOBAL_URL}
      WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS: "false"
      WEBHOOK_EVENTS_MESSAGES_UPSERT: "true"
      CONFIG_SESSION_PHONE_CLIENT: Barber Home
      CONFIG_SESSION_PHONE_NAME: Chrome
    volumes:
      - evolution_instances:/evolution/instances

  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    depends_on: [evolution]
    ports:
      - "80:80"
      - "443:443"
    environment:
      DOMAIN: ${DOMAIN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data

volumes:
  postgres_data:
  evolution_instances:
  caddy_data:
COMPOSE

docker compose pull -q
docker compose up -d --remove-orphans
echo "Evolution API running at https://$DOMAIN"
