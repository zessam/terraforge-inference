variable "project_id" {
  type = string
}

variable "secrets" {
  description = "Secrets Terraform generates and populates, as name => value."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "placeholder_secrets" {
  description = "Secrets created empty, with no version. Add the values by hand afterwards."
  type        = list(string)
  default     = []
}

variable "accessor_members" {
  description = "IAM members granted secretAccessor on every secret here."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
