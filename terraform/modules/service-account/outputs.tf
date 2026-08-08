output "email" {
  value = google_service_account.this.email
}

output "name" {
  description = "Fully qualified resource name."
  value       = google_service_account.this.name
}

output "member" {
  description = "IAM member string, ready to use in bindings."
  value       = "serviceAccount:${google_service_account.this.email}"
}
