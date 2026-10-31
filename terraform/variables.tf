variable "project_id" {
  type    = string
  default = "barber-app-259c1"
}

# us-central1 é uma das regiões com e2-micro na camada gratuita.
variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "public_url" {
  type    = string
  default = "https://barber-app-259c1.web.app"
}
