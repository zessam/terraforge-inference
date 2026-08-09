terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

resource "google_container_cluster" "this" {
  # The metadata server is enabled on the managed node pool, not here: this
  # cluster removes its default node pool, so it has no node_config to assert.
  #checkov:skip=CKV_GCP_69:GKE_METADATA is set on google_container_node_pool
  # Requires a Google Workspace group to bind RBAC to; not available here.
  #checkov:skip=CKV_GCP_65:no Workspace domain backing this project
  # Binary Authorization would block the upstream ghcr.io LiteLLM images until
  # attestors and an allowlist policy exist. Revisit when images are built here.
  #checkov:skip=CKV_GCP_66:no attestor infrastructure yet

  name     = "${var.name}-gke"
  project  = var.project_id
  location = var.location

  resource_labels = var.resource_labels

  # Logs pod-to-pod traffic that stays on a single node, which is otherwise
  # invisible to VPC flow logs.
  enable_intranode_visibility = true

  # Node config is owned by the node pool resource below, not by the cluster.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  # Set explicitly rather than relying on the provider default, so the policy
  # gate can assert it from the plan.
  enable_shielded_nodes = true

  networking_mode = "VPC_NATIVE"
  network         = var.network_id
  subnetwork      = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Required for pods to impersonate Google service accounts.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Client certificates are a long-lived credential that cannot be revoked
  # individually. Authenticate with IAM instead.
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Default-deny between pods until a NetworkPolicy allows it. Enabling this
  # restarts nodes as the Calico agent rolls out.
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  release_channel {
    channel = var.release_channel
  }
}

resource "google_container_node_pool" "this" {
  name       = "${var.name}-pool"
  project    = var.project_id
  location   = var.location
  cluster    = google_container_cluster.this.name
  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-balanced"
    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = var.node_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
