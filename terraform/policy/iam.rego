package main

import rego.v1

# Policy-as-code for IAM. Evaluated by conftest against the Terraform plan JSON.

primitive_roles := {"roles/owner", "roles/editor", "roles/viewer"}

public_members := {"allUsers", "allAuthenticatedUsers"}

# Project-wide primitive roles are too broad for any workload identity.
deny contains msg if {
	some resource in input.resource_changes
	resource.type in {"google_project_iam_member", "google_project_iam_binding"}
	resource.change.after.role in primitive_roles
	msg := sprintf(
		"%s: primitive role %s is not allowed; grant a predefined role instead",
		[resource.address, resource.change.after.role],
	)
}

# Nothing in this stack should ever be granted to the whole internet.
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

# Service account keys are long-lived credentials. This stack uses Workload
# Identity everywhere, so a key being created means something is misconfigured.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_service_account_key"
	msg := sprintf(
		"%s: service account keys are not allowed; use Workload Identity",
		[resource.address],
	)
}

# Secrets must be reachable only by named principals.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_secret_manager_secret_iam_member"
	resource.change.after.member in public_members
	msg := sprintf("%s: secrets must not be publicly accessible", [resource.address])
}
