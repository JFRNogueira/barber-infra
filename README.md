# Infraestrutura

Projeto GCP/Firebase: `barber-app-259c1`.

| Peça | Onde | Como publicar |
|---|---|---|
| Firestore (regras e índices) | `southamerica-east1` | `cd firebase && firebase deploy --only firestore` |
| Segredos | Secret Manager | `bash scripts/bootstrap-secrets.sh` (uma vez) |
| VM da Evolution | `us-central1-a`, e2-micro | `cd terraform && terraform apply` |
| Conectar o WhatsApp | Evolution | `NUMBER=55… bash scripts/evolution-connect.sh` (código de pareamento + `qrcode.png`) |
| Functions | `barber-back` | `firebase deploy --only functions` |
| Hosting | `barber-front` | `firebase deploy --only hosting` |
| Alertas, backup, orçamento, App Check, BigQuery | `terraform/ops.tf` | `terraform apply` (precisa de `terraform.tfvars` com `alert_email`) |
| Fotos dos barbeiros | bucket privado `barber-app-259c1-media` | criado; servido pela API |
| Homologação | projeto `barber-home-staging` | `bash scripts/create-staging.sh` |

## Ordem para colocar no ar

1. `bash scripts/bootstrap-secrets.sh`
2. `cd terraform && terraform init && terraform apply`
3. Preencher `barber-back/.env` (`EVOLUTION_URL` = `terraform output -raw evolution_url`, `BOT_PHONE`, `ADMIN_PHONE`) e publicar as Functions.
4. `NUMBER=55… bash scripts/evolution-connect.sh` e digitar o código de pareamento no WhatsApp do número do bot
   (Aparelhos conectados → Conectar com número de telefone). `status` mostra o estado; `reset` apaga a instância.
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
- [x] Segredos criados
- [x] Firebase Authentication inicializado (login do barbeiro)
- [x] VM da Evolution provisionada (`https://35-226-150-145.sslip.io`)
- [x] Functions publicadas; documentação da API em https://barber-app-259c1.web.app/api/docs
- [ ] Número do bot conectado na Evolution (teste: número pessoal do Johannes, com `BOT_ALLOWLIST`)
- [ ] Número dedicado do bot (antes do piloto)
- [x] Bucket de fotos e segredo `SMTP_URL` (como `unset`)
- [x] `terraform apply` do `ops.tf` (alertas, backup do Firestore, orçamento, App Check, dataset `barber_analytics`). Se o Terraform der `invalid_rapt`, use `export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)`. Para aplicar mudanças: `terraform plan -out=x.tfplan` e `terraform apply x.tfplan`
- [x] Homologação (`scripts/create-staging.sh`): https://barber-home-staging.web.app
- [ ] `SMTP_URL` real para os e-mails (Resend; ver barber-knowhow/04-arquitetura.md)
- [ ] Mercado Pago configurado
- [ ] Revisar o custo do IP público na primeira fatura

## Observações

- O `gcloud` deve usar a conta pessoal (Owner), não a service account do `serviceKey.json`:
  `gcloud config set account <seu e-mail>`. Para o Terraform: `export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)`.

- A VM tem snapshot diário do disco (sessão do WhatsApp).
- O projeto precisa manter a evolução para a API oficial do WhatsApp no futuro.
