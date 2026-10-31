#!/bin/bash
# Cria a instância "barber" na Evolution e salva o QR Code para conectar o número do bot.
#
#   bash scripts/evolution-connect.sh            # cria/reconecta e gera qrcode.png
#   bash scripts/evolution-connect.sh status     # estado da conexão
#
# Com NUMBER=55..., a Evolution devolve também um código de pareamento: no celular,
# Aparelhos conectados > Conectar um aparelho > "Conectar com número de telefone".
# Sem celular à mão para ler o QR, abra o qrcode.png e leia pelo WhatsApp.
set -euo pipefail

PROJECT=${PROJECT:-barber-app-259c1}
INSTANCE=${INSTANCE:-barber}
DIR=$(cd "$(dirname "$0")/.." && pwd)
URL=${EVOLUTION_URL:-$(terraform -chdir="$DIR/terraform" output -raw evolution_url | tr -d '\r')}
KEY=$(gcloud secrets versions access latest --secret=EVOLUTION_API_KEY --project "$PROJECT" | tr -d '\r\n')

api() { curl -fsS -H "apikey: $KEY" -H "Content-Type: application/json" "$@"; }

if [ "${1:-}" = "reset" ]; then
  api -X DELETE "$URL/instance/logout/$INSTANCE" >/dev/null 2>&1 || true
  api -X DELETE "$URL/instance/delete/$INSTANCE" >/dev/null
  echo "Instância $INSTANCE apagada."
  exit 0
fi

if [ "${1:-}" = "status" ]; then
  api "$URL/instance/connectionState/$INSTANCE"
  echo
  exit 0
fi

if ! api "$URL/instance/connectionState/$INSTANCE" >/dev/null 2>&1; then
  api -X POST "$URL/instance/create" \
    -d "{\"instanceName\":\"$INSTANCE\",\"integration\":\"WHATSAPP-BAILEYS\",\"qrcode\":true,\"rejectCall\":false,\"groupsIgnore\":true,\"alwaysOnline\":false,\"readMessages\":false${NUMBER:+,\"number\":\"$NUMBER\"}}" >/dev/null
  echo "Instância $INSTANCE criada."
fi

OUT="$DIR/qrcode.png"
QUERY=${NUMBER:+?number=$NUMBER}
api "$URL/instance/connect/$INSTANCE$QUERY" |
  python -c "
import sys, json, base64
d = json.load(sys.stdin)
b = d.get('base64') or ''
if not b:
    sys.exit('Sem QR Code (já conectado?): ' + json.dumps(d))
open(sys.argv[1], 'wb').write(base64.b64decode(b.split(',')[-1]))
if d.get('pairingCode'):
    print('Código de pareamento:', d['pairingCode'])
" "$OUT"
echo "QR Code salvo em $OUT (vale ~40 s; rode de novo se expirar)."
