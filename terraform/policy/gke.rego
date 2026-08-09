package main

import rego.v1

# Policy-as-code for the GKE cluster and node pools. Evaluated by conftest
# against the Terraform plan JSON (`terraform show -json tfplan`) — a stable,
# fully-resolved schema (not the parser-dependent HCL representation).
#
# Everything here is `warn`, not `deny`. These are hardening posture checks on a
# single-tenant study cluster: worth surfacing in the pipeline output, not worth
# blocking a deploy over. `deny` is reserved for rules where a violation would
# expose something to the public internet; see iam.rego and cloudsql.rego.

# Node pools should use a dedicated (non-default) service account.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not nc.service_account
	msg := sprintf("%s: node pool should set a dedicated service_account", [resource.address])
}

warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	nc.service_account == "default"
	msg := sprintf("%s: node pool should not use the default compute service account", [resource.address])
}

# Node pools should enable Shielded VM secure boot.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not secure_boot_enabled(nc)
	msg := sprintf("%s: node pool should enable shielded secure boot", [resource.address])
}

secure_boot_enabled(nc) if {
	some sic in nc.shielded_instance_config
	sic.enable_secure_boot == true
}

# Node pools should run the GKE metadata server (Workload Identity).
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not gke_metadata(nc)
	msg := sprintf("%s: node pool should set workload_metadata_config mode = GKE_METADATA", [resource.address])
}

gke_metadata(nc) if {
	some wmc in nc.workload_metadata_config
	wmc.mode == "GKE_METADATA"
}

# Cluster should enable Workload Identity.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	count(object.get(resource.change.after, "workload_identity_config", [])) == 0
	msg := sprintf("%s: cluster should enable Workload Identity", [resource.address])
}

# Cluster should enable Shielded Nodes.
#
# Written as `not shielded_nodes(after)` rather than `after.x != true`: when the
# attribute is absent the comparison is undefined, the rule body fails, and the
# check silently passes. The helper form fires on absent and on false alike.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	not shielded_nodes(resource.change.after)
	msg := sprintf("%s: cluster should set enable_shielded_nodes = true", [resource.address])
}

shielded_nodes(after) if after.enable_shielded_nodes == true

# Cluster should use private nodes.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	not private_nodes(resource.change.after)
	msg := sprintf("%s: cluster should enable private nodes", [resource.address])
}

private_nodes(after) if {
	some pcc in after.private_cluster_config
	pcc.enable_private_nodes == true
}

# The control plane is deliberately open so kubectl works from anywhere. It
# still requires IAM authentication. Promote to `deny` if this ever holds real
# data.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	some manc in resource.change.after.master_authorized_networks_config
	some cb in manc.cidr_blocks
	cb.cidr_block == "0.0.0.0/0"
	msg := sprintf("%s: control plane is open to 0.0.0.0/0 (accepted for this environment)", [resource.address])
}
