terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_artifact_registry_repository" "this" {
  # CMEK means running and paying for a KMS key, plus owning its rotation and
  # the risk of locking the registry out. Not warranted here: contents are
  # public base images, and Google-managed encryption at rest is always on.
  #checkov:skip=CKV_GCP_84:Google-managed encryption is sufficient for this registry

  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format

  labels = var.labels
}

# Repository-scoped access, rather than a project-wide artifactregistry role.
resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = toset(var.readers)

  project    = var.project_id
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  for_each = toset(var.writers)

  project    = var.project_id
  location   = google_artifact_registry_repository.this.location
  repository = google_artifact_registry_repository.this.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}
