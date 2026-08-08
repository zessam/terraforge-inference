terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# This module reserves the address only. The load balancer itself is created by
# GKE when the Ingress is applied, referencing this address by name:
#
#   kubernetes.io/ingress.global-static-ip-name: <address_name>
#
# Reserving it here means the IP is stable and known before the workload exists.
resource "google_compute_global_address" "this" {
  name         = "${var.name}-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
}

locals {
  # Unlike an AWS ELB, a GCP load balancer has no DNS name of its own — it is an
  # IP only. A wildcard DNS service closes the gap: <ip>.nip.io resolves to that
  # IP with no registration and no records to manage. Because the IP above is
  # reserved and static, the hostname is stable too.
  wildcard_domain = "${google_compute_global_address.this.address}.${var.wildcard_dns_suffix}"

  hostname = var.domain != "" ? var.domain : (var.use_wildcard_dns ? local.wildcard_domain : "")

  # Kept free of computed values so count stays resolvable at plan time.
  create_certificate = var.domain != "" || var.use_wildcard_dns
}

# Google-managed certificates cannot be issued for a bare IP, but they can for a
# hostname — including a wildcard-DNS one, since validation only requires the
# name to resolve to this load balancer.
resource "google_compute_managed_ssl_certificate" "this" {
  count = local.create_certificate ? 1 : 0

  name    = "${var.name}-cert"
  project = var.project_id

  managed {
    domains = [local.hostname]
  }

  lifecycle {
    create_before_destroy = true
  }
}
