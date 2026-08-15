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
  # TLS would require the LiteLLM chart to trust the Memorystore CA, which its
  # redis config does not expose. Traffic never leaves the VPC and AUTH is on.
  # Flip transit_encryption_mode to SERVER_AUTHENTICATION once the client can
  # be given the CA bundle.
  #checkov:skip=CKV_GCP_97:private VPC path with AUTH enabled; client cannot supply a CA yet

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

  # Instance-wide Redis parameters. maxmemory-policy is the one that matters
  # here: Langfuse runs its ingestion queue on this instance, and an eviction
  # policy that discards keys under pressure would silently drop queued jobs.
  redis_configs = var.redis_configs

  labels = var.labels
}
