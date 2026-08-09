package main

import rego.v1

# Policy-as-code for IAM, evaluated against the Terraform plan JSON.
#
# `deny` here is limited to granting access to the public internet. Overly broad
# but non-public grants are `warn`.

public_members := {"allUsers", "allAuthenticatedUsers"}

primitive_roles := {"roles/owner", "roles/editor", "roles/viewer"}

# DENY: nothing in this stack should ever be granted to the whole internet.
deny contains msg if {
	some resource in input.resource_changes
	contains(resource.type, "iam_member")
	resource.change.after.member in public_members
	msg := sprintf(
		"%s: %s must not be granted access",
		[resource.address, resource.change.after.member],
	)
}

deny contains msg if {
	some resource in input.resource_changes
	contains(resource.type, "iam_binding")
	some member in resource.change.after.members
	member in public_members
	msg := sprintf("%s: %s must not be granted access", [resource.address, member])
}

# DENY: exported service account keys are long-lived credentials that leak.
# This stack uses Workload Identity everywhere, so one appearing means something
# is misconfigured.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_service_account_key"
	msg := sprintf(
		"%s: service account keys are not allowed; use Workload Identity",
		[resource.address],
	)
}

# Project-wide primitive roles are broader than any workload needs.
warn contains msg if {
	some resource in input.resource_changes
	resource.type in {"google_project_iam_member", "google_project_iam_binding"}
	resource.change.after.role in primitive_roles
	msg := sprintf(
		"%s: primitive role %s is broad; prefer a predefined role",
		[resource.address, resource.change.after.role],
	)
}
