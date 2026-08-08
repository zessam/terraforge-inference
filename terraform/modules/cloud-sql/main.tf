terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_password" "user" {
  length  = 32
  special = false
}

# Private IP on the cluster's VPC, reached directly by workloads in GKE. This is
# what the LiteLLM Helm charts expect: they connect to a host:port, not through
# a Cloud SQL Auth Proxy sidecar. Requires Private Services Access on the VPC.
resource "google_sql_database_instance" "this" {
  name             = "${var.name}-pg"
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  deletion_protection = var.deletion_protection

  settings {
    # Set explicitly: the API now defaults new instances to ENTERPRISE_PLUS,
    # which rejects shared-core tiers and requires db-perf-optimized-N-*.
    edition = var.edition

    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = var.enable_public_ip
      private_network = var.private_network
      ssl_mode        = var.ssl_mode
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.point_in_time_recovery
      start_time                     = "03:00"
    }
  }
}

resource "google_sql_database" "this" {
  for_each = toset(var.databases)

  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "this" {
  name     = var.user_name
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = random_password.user.result
}
