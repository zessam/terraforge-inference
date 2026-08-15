# Policy gate for the rendered LiteLLM manifests, in the same shape as
# terraform/policy: conftest runs it against what will actually be applied,
# not against the values file that produced it. Rendering first is the point —
# a chart default nobody set is still a chart default that ships.
package main

import rego.v1

# --- images -----------------------------------------------------------------

deny contains msg if {
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("%s/%s: image uses a moving tag (%s); pin a version so rollbacks are deterministic", [kind_name, c.name, c.image])
}

deny contains msg if {
	some c in containers
	not contains(c.image, ":")
	msg := sprintf("%s/%s: image has no tag (%s)", [kind_name, c.name, c.image])
}

# --- resource bounds --------------------------------------------------------

# Without requests the scheduler cannot place pods honestly and the HPA has no
# denominator to scale against.
deny contains msg if {
	some c in containers
	not c.resources.requests.cpu
	msg := sprintf("%s/%s: no CPU request", [kind_name, c.name])
}

deny contains msg if {
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("%s/%s: no memory limit; one leaking pod can evict its neighbours", [kind_name, c.name])
}

# --- privilege --------------------------------------------------------------

deny contains msg if {
	some c in containers
	c.securityContext.privileged
	msg := sprintf("%s/%s: privileged container", [kind_name, c.name])
}

deny contains msg if {
	some c in containers
	c.securityContext.allowPrivilegeEscalation
	msg := sprintf("%s/%s: allowPrivilegeEscalation is true", [kind_name, c.name])
}

deny contains msg if {
	input.kind in workload_kinds
	pod_spec.hostNetwork
	msg := sprintf("%s: hostNetwork", [kind_name])
}

deny contains msg if {
	input.kind in workload_kinds
	some v in object.get(pod_spec, "volumes", [])
	v.hostPath
	msg := sprintf("%s: hostPath volume %s", [kind_name, v.name])
}

# --- secrets ----------------------------------------------------------------

# Credentials belong in Secret Manager and reach the cluster through an
# ExternalSecret. A literal Secret in the repo is a credential in git.
deny contains msg if {
	input.kind == "Secret"
	count(object.get(input, "data", {})) > 0
	msg := sprintf("Secret/%s carries inline data; use an ExternalSecret backed by Secret Manager", [input.metadata.name])
}

deny contains msg if {
	input.kind == "Secret"
	count(object.get(input, "stringData", {})) > 0
	msg := sprintf("Secret/%s carries inline stringData; use an ExternalSecret backed by Secret Manager", [input.metadata.name])
}

# --- helpers ----------------------------------------------------------------

workload_kinds := {"Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob"}

kind_name := sprintf("%s/%s", [input.kind, object.get(input.metadata, "name", "<unnamed>")])

pod_spec := input.spec.template.spec if {
	input.kind in {"Deployment", "StatefulSet", "DaemonSet", "Job"}
}

pod_spec := input.spec.jobTemplate.spec.template.spec if input.kind == "CronJob"

containers contains c if {
	some c in object.get(pod_spec, "containers", [])
}

containers contains c if {
	some c in object.get(pod_spec, "initContainers", [])
}
