# Infraestrutura

Projeto GCP/Firebase: `barber-app-259c1`.

| Peça | Onde | Como publicar |
|---|---|---|
| Firestore (regras e índices) | `southamerica-east1` | `cd firebase && firebase deploy --only firestore` |
| Segredos | Secret Manager | `bash scripts/bootstrap-secrets.sh` (uma vez) |
| VM da Evolution | `us-central1-a`, e2-micro | `cd terraform && terraform apply` |
| Conectar o WhatsApp | Evolution | `bash scripts/evolution-connect.sh` (gera `qrcode.png`) |
| Functions | `barber-back` | `firebase deploy --only functions` |
| Hosting | `barber-front` | `firebase deploy --only hosting` |

## Ordem para colocar no ar

1. `bash scripts/bootstrap-secrets.sh`
2. `cd terraform && terraform init && terraform apply`
3. Preencher `barber-back/.env` (`EVOLUTION_URL` = `terraform output -raw evolution_url`, `BOT_PHONE`, `ADMIN_PHONE`) e publicar as Functions.
4. `bash scripts/evolution-connect.sh` e ler o QR Code com o número dedicado.
5. Cadastrar barbeiros (`barber-back`, `npm run barber`).
6. Mercado Pago: criar a aplicação marketplace, gravar `MP_ACCESS_TOKEN`, `MP_CLIENT_SECRET`, `MP_WEBHOOK_SECRET`
   no Secret Manager e `MP_CLIENT_ID` no `.env`; URL de retorno do OAuth:
   `https://barber-app-259c1.web.app/api/mercadopago/callback`; webhook:
   `https://barber-app-259c1.web.app/api/webhooks/mercadopago` (evento "Pagamentos"). Publicar as Functions de novo.

## Checklist

- [x] Projeto Firebase criado
- [x] Hosting do front publicado
- [x] Firestore criado (`southamerica-east1`), regras e índices publicados
- [x] APIs habilitadas (Functions, Cloud Build, Run, Scheduler, Secret Manager, Geocoding)
- [ ] Segredos criados
- [ ] VM da Evolution provisionada e número conectado
- [ ] Functions publicadas
- [ ] Mercado Pago configurado
- [ ] Revisar o custo do IP público na primeira fatura

## Observações

- A VM tem snapshot diário do disco (sessão do WhatsApp).
- O projeto precisa manter a evolução para a API oficial do WhatsApp no futuro.
