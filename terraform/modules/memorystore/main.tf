terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Redis for LiteLLM rate limiting, router state, and cross-replica caching.
# Reachable only from the authorized VPC — it has no public address.
resource "google_redis_instance" "this" {
  name    = "${var.name}-redis"
  project = var.project_id
  region  = var.region

  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  authorized_network = var.authorized_network
  connect_mode       = var.connect_mode

  # Generates a password; exposed as auth_string for the app secret.
  auth_enabled = true

  # DISABLED keeps the client config simple. In-transit traffic stays inside
  # the VPC. Switch to SERVER_AUTHENTICATION if the client can supply the CA.
  transit_encryption_mode = var.transit_encryption_mode

  labels = var.labels
}
