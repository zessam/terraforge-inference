terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Object storage for Langfuse: raw ingestion events, media uploads, and batch
# exports. Langfuse writes every incoming event here before processing it, so
# that a database outage loses nothing — which is also why this is not optional
# for a v3 deployment.
resource "google_storage_bucket" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  # Reads and writes go through IAM only; the policy in terraform/policy
  # requires both of these.
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  # Objects are recoverable for a week after an accidental delete or overwrite.
  versioning {
    enabled = var.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.retention_days > 0 ? [1] : []

    content {
      condition {
        age = var.retention_days
      }
      action {
        type = "Delete"
      }
    }
  }

  # Noncurrent versions are the expensive part of versioning: without this they
  # accumulate forever.
  dynamic "lifecycle_rule" {
    for_each = var.versioning ? [1] : []

    content {
      condition {
        days_since_noncurrent_time = var.noncurrent_version_days
      }
      action {
        type = "Delete"
      }
    }
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "writers" {
  for_each = toset(var.writers)

  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectAdmin"
  member = each.value
}
