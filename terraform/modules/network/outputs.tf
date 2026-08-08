output "network_id" {
  value = google_compute_network.this.id
}

output "network_name" {
  value = google_compute_network.this.name
}

output "subnet_id" {
  value = google_compute_subnetwork.this.id
}

output "pods_range_name" {
  description = "Secondary range name for GKE pod IPs."
  value       = local.pods_range
}

output "services_range_name" {
  description = "Secondary range name for GKE service IPs."
  value       = local.services_range
}

output "nat_name" {
  value = google_compute_router_nat.this.name
}
