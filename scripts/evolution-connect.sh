#!/bin/bash
# Cria a instância "barber" na Evolution e salva o QR Code para conectar o número do bot.
#
#   bash scripts/evolution-connect.sh            # cria/reconecta e gera qrcode.png
#   bash scripts/evolution-connect.sh status     # estado da conexão
#
# Abra o qrcode.png e leia com o WhatsApp do número dedicado:
# Configurações > Aparelhos conectados > Conectar um aparelho.
set -euo pipefail

PROJECT=${PROJECT:-barber-app-259c1}
INSTANCE=${INSTANCE:-barber}
DIR=$(cd "$(dirname "$0")/.." && pwd)
URL=${EVOLUTION_URL:-$(terraform -chdir="$DIR/terraform" output -raw evolution_url)}
KEY=$(gcloud secrets versions access latest --secret=EVOLUTION_API_KEY --project "$PROJECT")

api() { curl -fsS -H "apikey: $KEY" -H "Content-Type: application/json" "$@"; }

if [ "${1:-}" = "status" ]; then
  api "$URL/instance/connectionState/$INSTANCE"
  echo
  exit 0
fi

if ! api "$URL/instance/connectionState/$INSTANCE" >/dev/null 2>&1; then
  api -X POST "$URL/instance/create" \
    -d "{\"instanceName\":\"$INSTANCE\",\"integration\":\"WHATSAPP-BAILEYS\",\"qrcode\":true,\"rejectCall\":true,\"msgCall\":\"Não atendemos ligações por aqui. Mande uma mensagem.\",\"groupsIgnore\":true,\"alwaysOnline\":false,\"readMessages\":true}" >/dev/null
  echo "Instância $INSTANCE criada."
fi

OUT="$DIR/qrcode.png"
api "$URL/instance/connect/$INSTANCE" |
  python -c "import sys,json,base64; d=json.load(sys.stdin); b=d.get('base64') or ''; sys.exit('Sem QR Code (já conectado?): '+json.dumps(d)) if not b else open(sys.argv[1],'wb').write(base64.b64decode(b.split(',')[-1]))" "$OUT"
echo "QR Code salvo em $OUT (vale ~40 s; rode de novo se expirar)."
