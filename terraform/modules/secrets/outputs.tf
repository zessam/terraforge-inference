output "secret_ids" {
  description = "All secret names created."
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}

output "populated_secret_ids" {
  description = "Secrets that already hold a value."
  value       = tolist(local.managed_names)
}

output "empty_secret_ids" {
  description = "Secrets created with no version. Add values before deploying."
  value       = tolist(local.placeholder_names)
}
