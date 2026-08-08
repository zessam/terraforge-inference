output "enabled" {
  description = "Enabled service names. Depend on this to order resources after API enablement."
  value       = [for s in google_project_service.this : s.service]
}
