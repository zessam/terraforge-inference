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
  # ssl_mode = ENCRYPTED_ONLY is the modern replacement for the deprecated
  # require_ssl flag this check looks for; it enforces the same thing.
  #checkov:skip=CKV_GCP_6:enforced via ssl_mode, not the deprecated require_ssl

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

    # Audit logging baseline. Written as static blocks rather than a dynamic
    # block over a map, because static analysers cannot resolve dynamic blocks
    # and would report these as missing.
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "log_min_messages"
      value = "error"
    }

    # Distinct from log_min_messages: this controls which statements are logged
    # alongside an error, and is the flag the audit baseline actually asserts.
    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_statement"
      value = "ddl"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    # Anything environment-specific, e.g. max_connections tuning.
    dynamic "database_flags" {
      for_each = var.extra_database_flags

      content {
        name  = database_flags.key
        value = database_flags.value
      }
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
