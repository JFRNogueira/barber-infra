# Terraform — VM da Evolution API

Provisiona no GCP (`us-central1`, camada gratuita):

- VM `e2-micro` com disco Standard de 30 GB e 2 GB de swap;
- IP externo fixo e firewall liberando 80/443;
- Evolution API v2.3.7 + Postgres + Caddy (HTTPS automático em `<ip>.sslip.io`);
- snapshot diário do disco (7 dias), que guarda a sessão do WhatsApp.

A VM lê `EVOLUTION_API_KEY` e `EVOLUTION_WEBHOOK_TOKEN` do Secret Manager no boot,
então os segredos precisam existir antes do `apply` (ver `../scripts/bootstrap-secrets.sh`).

## Comandos

```bash
cd terraform
terraform init
terraform apply
terraform output evolution_url   # vai em EVOLUTION_URL no .env do barber-back
```

Depois do primeiro boot (~5 min), crie a instância e leia o QR Code com
`../scripts/evolution-connect.sh`.

## Observações

- O IP externo em uso custa cerca de US$ 3,65/mês; confirmar na primeira fatura.
- Número de WhatsApp dedicado e aquecido (ver `barber-knowhow/06-whatsapp.md`).
- O startup script roda a cada boot; para aplicar mudanças nele, `terraform apply` e reinicie a VM.
