variable "project_id" {
  type = string
}

variable "name" {
  description = "Name prefix for the instance."
  type        = string
}

variable "region" {
  type = string
}

variable "database_version" {
  type    = string
  default = "POSTGRES_18"
}

variable "extra_database_flags" {
  description = "Additional Postgres flags, merged with the audit-logging baseline set in the module."
  type        = map(string)
  default     = {}
}

variable "edition" {
  description = "ENTERPRISE supports shared-core tiers (db-f1-micro, db-g1-small). ENTERPRISE_PLUS requires db-perf-optimized-N-* and costs substantially more."
  type        = string
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.edition)
    error_message = "edition must be ENTERPRISE or ENTERPRISE_PLUS."
  }
}

variable "tier" {
  type    = string
  default = "db-g1-small"
}

variable "availability_type" {
  type    = string
  default = "ZONAL"
}

variable "disk_size_gb" {
  type    = number
  default = 10
}

variable "databases" {
  description = "Databases to create on the instance."
  type        = list(string)
  default     = []
}

variable "user_name" {
  description = "Application database user."
  type        = string
}

variable "private_network" {
  description = "VPC to attach a private IP on. Requires Private Services Access to exist first."
  type        = string
  default     = null
}

variable "enable_public_ip" {
  description = "Adds a public IP. Not needed when workloads reach the instance privately."
  type        = bool
  default     = false
}

variable "ssl_mode" {
  description = "ENCRYPTED_ONLY rejects plaintext. Postgres clients defaulting to sslmode=prefer negotiate TLS automatically, so this is safe with the Helm charts."
  type        = string
  default     = "ENCRYPTED_ONLY"
}

variable "point_in_time_recovery" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  description = "Set true for anything that is not a lab."
  type        = bool
  default     = false
}
