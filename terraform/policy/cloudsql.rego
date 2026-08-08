package main

import rego.v1

# Policy-as-code for Cloud SQL. Evaluated by conftest against the Terraform plan
# JSON (`terraform show -json tfplan`) — a stable, fully-resolved schema.
#
# A public IP is permitted: the instance is reached through the Cloud SQL Auth
# Proxy, which authenticates with IAM over TLS. What is not permitted is an
# authorized network that lets anything connect directly.

# Connections must be encrypted.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	some s in resource.change.after.settings
	some ip in s.ip_configuration
	not encrypted_only(ip)
	msg := sprintf("%s: must set ssl_mode = \"ENCRYPTED_ONLY\"", [resource.address])
}

encrypted_only(ip) if ip.ssl_mode == "ENCRYPTED_ONLY"

# No direct network path from the internet to the database.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	some s in resource.change.after.settings
	some ip in s.ip_configuration
	some an in ip.authorized_networks
	an.value == "0.0.0.0/0"
	msg := sprintf("%s: authorized_networks must not allow 0.0.0.0/0", [resource.address])
}

# Backups must be on. LiteLLM keeps virtual keys, budgets, and spend here.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	some s in resource.change.after.settings
	not backups_enabled(s)
	msg := sprintf("%s: backup_configuration must be enabled", [resource.address])
}

backups_enabled(s) if {
	some bc in s.backup_configuration
	bc.enabled == true
}

# Database passwords must never be hardcoded.
#
# This reads `configuration`, not `resource_changes`. In resource_changes a
# generated password and a hardcoded one are both just a resolved string, so
# they cannot be told apart. In configuration a literal appears as
# `constant_value` while a generated one appears as `references`, which is the
# distinction we actually care about.
deny contains msg if {
	walk(input.configuration, [_, node])
	node.type == "google_sql_user"
	node.expressions.password.constant_value
	msg := sprintf("%s: password must not be a hardcoded literal; use random_password or a secret", [node.address])
}
