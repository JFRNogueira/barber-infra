terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_project" "this" {}

locals {
  # Hostname com HTTPS automático (Let's Encrypt via Caddy) sem precisar de domínio próprio.
  evolution_domain   = "${replace(google_compute_address.evolution.address, ".", "-")}.sslip.io"
  vm_service_account = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

# IP fixo: as Functions chamam a Evolution por este endereço.
resource "google_compute_address" "evolution" {
  name   = "barber-evolution-ip"
  region = var.region
}

resource "google_compute_firewall" "evolution_https" {
  name    = "barber-evolution-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["evolution"]
}

# A VM lê a API key e o token do webhook direto do Secret Manager no boot.
resource "google_secret_manager_secret_iam_member" "vm_secrets" {
  for_each  = toset(["EVOLUTION_API_KEY", "EVOLUTION_WEBHOOK_TOKEN"])
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.vm_service_account}"
}

resource "google_compute_instance" "evolution_vm" {
  name         = "barber-evolution-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.evolution.address
    }
  }

  service_account {
    email  = local.vm_service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    evolution-domain = local.evolution_domain
    webhook-base-url = "${var.public_url}/api/webhooks/evolution"
  }

  metadata_startup_script = file("${path.module}/scripts/startup.sh")

  tags = ["barber", "evolution"]

  depends_on = [google_secret_manager_secret_iam_member.vm_secrets]
}

# Snapshot diário do disco: guarda a sessão do WhatsApp para não precisar ler o QR Code de novo.
resource "google_compute_resource_policy" "daily_snapshot" {
  name   = "barber-evolution-daily-snapshot"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "06:00"
      }
    }
    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "evolution_snapshot" {
  name = google_compute_resource_policy.daily_snapshot.name
  disk = google_compute_instance.evolution_vm.name
  zone = var.zone
}

output "evolution_url" {
  value = "https://${local.evolution_domain}"
}

output "evolution_ip" {
  value = google_compute_address.evolution.address
}
