# Infraestrutura

## Objetivo

Provisionar a base da plataforma conforme o MVP decidido em 31/10/2026.

## Stack atual

- Firebase Hosting para a web app
- Firebase Functions para regras e webhooks
- Firestore para dados do produto
- Cloud Tasks + Cloud Scheduler para lembretes e tarefas automáticas
- VM e2-micro para Evolution API
- Mercado Pago para Pix e split
- Google Geocoding para resolver bairro por endereço

## Checklist inicial

- [ ] Projeto Firebase criado
- [ ] Hosting do front habilitado
- [ ] Firestore configurado
- [ ] Cloud Functions inicializadas
- [ ] Cloud Scheduler definido
- [ ] VM da Evolution provisionada
- [ ] Secrets do Mercado Pago armazenados
- [ ] Chaves da Google Geocoding ativadas
- [ ] Regras de segurança do Firestore revisadas

## Observações

- O custo do IP público da VM deve ser validado antes do deploy em produção.
- A VM da Evolution deve ter backup da sessão do WhatsApp.
- O projeto precisa manter a evolução para API oficial do WhatsApp no futuro.
