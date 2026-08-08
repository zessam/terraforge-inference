output "host" {
  description = "Private IP of the Redis endpoint."
  value       = google_redis_instance.this.host
}

output "port" {
  value = google_redis_instance.this.port
}

output "auth_string" {
  description = "Generated Redis password."
  value       = google_redis_instance.this.auth_string
  sensitive   = true
}

output "name" {
  value = google_redis_instance.this.name
}
