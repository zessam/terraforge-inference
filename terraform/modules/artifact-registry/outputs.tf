output "repository_id" {
  value = google_artifact_registry_repository.this.repository_id
}

output "name" {
  value = google_artifact_registry_repository.this.name
}

output "url" {
  description = "Image prefix, e.g. europe-west8-docker.pkg.dev/trisec-lab/terraforge-dev."
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
