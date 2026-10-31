# Operação (plano de ação, fase 1): alertas, backup do Firestore, orçamento e App Check.

variable "alert_email" {
  type        = string
  description = "E-mail que recebe os alertas e o aviso de orçamento"
}

variable "billing_account" {
  type    = string
  default = "011041-BEB844-8228CB"
}

variable "monthly_budget" {
  type        = number
  default     = 20
  description = "Orçamento mensal, na moeda da conta de faturamento"
}

variable "web_app_id" {
  type    = string
  default = "1:290173477201:web:340981b1b9673366c7f370"
}

resource "google_project_service" "ops" {
  for_each           = toset(["billingbudgets.googleapis.com", "firebaseappcheck.googleapis.com", "recaptchaenterprise.googleapis.com"])
  service            = each.value
  disable_on_destroy = false
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Equipe Barber Home"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# Erros nas Functions (api, runJobs, dailyAgenda): qualquer log ERROR em 5 minutos.
resource "google_logging_metric" "function_errors" {
  name   = "barber_function_errors"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=(\"api\" OR \"runjobs\" OR \"dailyagenda\") AND severity>=ERROR"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "function_errors" {
  display_name = "Barber Home: erros nas Functions"
  combiner     = "OR"
  conditions {
    display_name = "Erros nos últimos 5 minutos"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.function_errors.name}\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  alert_strategy {
    auto_close = "3600s"
  }
  documentation {
    content = "Veja os logs: Cloud Run → serviço api/runjobs/dailyagenda → Logs (severity ERROR)."
  }
}

# Evolution (WhatsApp) fora do ar: checagem HTTPS a cada 5 minutos.
resource "google_monitoring_uptime_check_config" "evolution" {
  display_name = "Barber Home: Evolution API"
  timeout      = "10s"
  period       = "300s"
  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }
  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = local.evolution_domain
    }
  }
}

resource "google_monitoring_alert_policy" "evolution_down" {
  display_name = "Barber Home: WhatsApp (Evolution) fora do ar"
  combiner     = "OR"
  conditions {
    display_name = "Checagem falhando"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.evolution.uptime_check_id}\" AND resource.type=\"uptime_url\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "600s"
      aggregations {
        alignment_period     = "600s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.email.id]
  documentation {
    content = "A Evolution não responde. Veja a VM barber-evolution-vm (us-central1-a) e `bash scripts/evolution-connect.sh status`."
  }
}

# Backup diário do Firestore, guardado por 7 dias.
resource "google_firestore_backup_schedule" "daily" {
  database  = "(default)"
  retention = "604800s"
  daily_recurrence {}
}

# Aviso de orçamento: 50%, 90% e 100% do valor mensal.
resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "Barber Home (mensal)"
  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }
  amount {
    specified_amount {
      units = tostring(var.monthly_budget)
    }
  }
  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }
  depends_on = [google_project_service.ops]
}

# App Check: reCAPTCHA Enterprise no app web. A API só bloqueia com APP_CHECK_ENFORCE=true.
resource "google_recaptcha_enterprise_key" "web" {
  display_name = "Barber Home (App Check)"
  web_settings {
    integration_type  = "SCORE"
    allowed_domains   = ["barber-app-259c1.web.app", "barber-app-259c1.firebaseapp.com", "localhost"]
    allow_amp_traffic = false
  }
  depends_on = [google_project_service.ops]
}

resource "google_firebase_app_check_recaptcha_enterprise_config" "web" {
  app_id    = var.web_app_id
  site_key  = google_recaptcha_enterprise_key.web.name
  token_ttl = "3600s"
}

output "recaptcha_site_key" {
  value       = reverse(split("/", google_recaptcha_enterprise_key.web.name))[0]
  description = "Vai em VITE_RECAPTCHA_SITE_KEY no barber-front (.env.production)"
}

# Dados de uso para análise (fase 3): a Function analyticsExport recarrega as tabelas todo dia.
resource "google_bigquery_dataset" "analytics" {
  dataset_id  = "barber_analytics"
  location    = "southamerica-east1"
  description = "Barber Home: agendamentos, barbeiros e clientes (anonimizados), recarregados diariamente"
}
