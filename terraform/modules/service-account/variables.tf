variable "project_id" {
  description = "Project the service account lives in."
  type        = string
}

variable "account_id" {
  description = "Service account ID, the part before the @."
  type        = string
}

variable "display_name" {
  description = "Human-readable name."
  type        = string
  default     = ""
}

variable "project_roles" {
  description = "Project-level IAM roles to grant this service account."
  type        = list(string)
  default     = []
}

variable "workload_identity_users" {
  description = "Kubernetes service accounts allowed to impersonate this one, as \"namespace/name\"."
  type        = list(string)
  default     = []
}
