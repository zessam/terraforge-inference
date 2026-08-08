output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Pass to the Cloud SQL Auth Proxy sidecar."
  value       = google_sql_database_instance.this.connection_name
}

output "user_name" {
  value = google_sql_user.this.name
}

output "user_password" {
  description = "Generated password for the application user."
  value       = random_password.user.result
  sensitive   = true
}
