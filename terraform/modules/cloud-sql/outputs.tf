output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Instance connection name, for the Auth Proxy or gcloud."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP on the VPC. This is the database host the Helm chart connects to."
  value       = google_sql_database_instance.this.private_ip_address
}

output "user_name" {
  value = google_sql_user.this.name
}

output "user_password" {
  description = "Generated password for the application user."
  value       = random_password.user.result
  sensitive   = true
}
