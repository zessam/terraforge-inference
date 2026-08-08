output "name" {
  value = google_container_cluster.this.name
}

output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "location" {
  value = google_container_cluster.this.location
}

output "workload_pool" {
  value = "${var.project_id}.svc.id.goog"
}
