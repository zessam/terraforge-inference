terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_compute_network" "this" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name          = "${var.name}-subnet"
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range
    ip_cidr_range = var.services_cidr
  }
}

# Private Services Access: a range handed to Google so managed services
# (Cloud SQL, Memorystore) can be peered into this VPC with private IPs.
resource "google_compute_global_address" "psa" {
  count = var.enable_private_services_access ? 1 : 0

  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  count = var.enable_private_services_access ? 1 : 0

  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa[0].name]

  # Without this, destroying the VPC fails because the peering cannot be
  # removed while Google still holds it.
  deletion_policy = "ABANDON"
}

resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

# Private GKE nodes have no external IP. Without NAT they cannot pull images
# and cannot reach RunPod over Tailscale. This is not optional.
resource "google_compute_router_nat" "this" {
  name   = "${var.name}-nat"
  router = google_compute_router.this.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
