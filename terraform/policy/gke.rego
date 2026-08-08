package main

import rego.v1

# Policy-as-code for the GKE cluster and node pools. Evaluated by conftest
# against the Terraform plan JSON (`terraform show -json tfplan`) — a stable,
# fully-resolved schema (not the parser-dependent HCL representation).

# Node pools must use a dedicated (non-default) service account.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not nc.service_account
	msg := sprintf("%s: node pool must set a dedicated service_account", [resource.address])
}

deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	nc.service_account == "default"
	msg := sprintf("%s: node pool must not use the default compute service account", [resource.address])
}

# Node pools must enable Shielded VM secure boot.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not secure_boot_enabled(nc)
	msg := sprintf("%s: node pool must enable shielded secure boot", [resource.address])
}

secure_boot_enabled(nc) if {
	some sic in nc.shielded_instance_config
	sic.enable_secure_boot == true
}

# Node pools must run the GKE metadata server (Workload Identity).
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_node_pool"
	some nc in resource.change.after.node_config
	not gke_metadata(nc)
	msg := sprintf("%s: node pool must set workload_metadata_config mode = GKE_METADATA", [resource.address])
}

gke_metadata(nc) if {
	some wmc in nc.workload_metadata_config
	wmc.mode == "GKE_METADATA"
}

# Cluster must enable Workload Identity.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	count(object.get(resource.change.after, "workload_identity_config", [])) == 0
	msg := sprintf("%s: cluster must enable Workload Identity", [resource.address])
}

# Cluster must enable Shielded Nodes.
#
# Written as `not shielded_nodes(after)` rather than `after.x != true`: when the
# attribute is absent the comparison is undefined, the rule body fails, and the
# check silently passes. The helper form fires on absent and on false alike.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	not shielded_nodes(resource.change.after)
	msg := sprintf("%s: cluster must set enable_shielded_nodes = true", [resource.address])
}

shielded_nodes(after) if after.enable_shielded_nodes == true

# Control-plane exposure is a warn, not a deny: this is a study cluster and the
# endpoint is deliberately open so kubectl works from anywhere. It still requires
# IAM authentication. Promote to `deny` if this ever carries real data.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	some manc in resource.change.after.master_authorized_networks_config
	some cb in manc.cidr_blocks
	cb.cidr_block == "0.0.0.0/0"
	msg := sprintf("%s: control plane is open to 0.0.0.0/0 (accepted for this environment)", [resource.address])
}

# Cluster must use private nodes.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_container_cluster"
	not private_nodes(resource.change.after)
	msg := sprintf("%s: cluster must enable private nodes", [resource.address])
}

private_nodes(after) if {
	some pcc in after.private_cluster_config
	pcc.enable_private_nodes == true
}
