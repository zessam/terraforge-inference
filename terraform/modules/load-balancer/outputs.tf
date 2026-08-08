output "address" {
  description = "The reserved public IP."
  value       = google_compute_global_address.this.address
}

output "address_name" {
  description = "Ingress annotation: kubernetes.io/ingress.global-static-ip-name"
  value       = google_compute_global_address.this.name
}

output "hostname" {
  description = "DNS name for the endpoint. Empty only if wildcard DNS is disabled with no domain set."
  value       = local.hostname
}

output "endpoint" {
  description = "Base URL for the gateway."
  value       = local.hostname == "" ? "http://${google_compute_global_address.this.address}" : "https://${local.hostname}"
}

output "certificate_name" {
  description = "Ingress annotation: ingress.gcp.kubernetes.io/pre-shared-cert. Not networking.gke.io/managed-certificates — that one refers to the ManagedCertificate CRD, whereas this certificate is a Compute resource created here. Empty when no certificate is created."
  value       = local.create_certificate ? google_compute_managed_ssl_certificate.this[0].name : ""
}
