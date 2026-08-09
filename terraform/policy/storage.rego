package main

import rego.v1

# Policy-as-code for storage buckets, evaluated against the Terraform plan JSON.
#
# This stack creates no buckets today — the Terraform state bucket lives outside
# it. Kept for when one appears.

# DENY: a publicly readable bucket.
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	resource.change.after.public_access_prevention != "enforced"
	msg := sprintf("%s: bucket must set public_access_prevention = \"enforced\"", [resource.address])
}

# Legacy ACLs are harder to reason about than IAM.
warn contains msg if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	resource.change.after.uniform_bucket_level_access != true
	msg := sprintf("%s: bucket should enable uniform_bucket_level_access", [resource.address])
}
