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

variable "authorized_network" {
  description = "VPC allowed to reach the instance."
  type        = string
}

variable "tier" {
  description = "BASIC is a single node with no failover. STANDARD_HA adds a replica and roughly doubles the cost."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "tier must be BASIC or STANDARD_HA."
  }
}

variable "memory_size_gb" {
  type    = number
  default = 1
}

variable "redis_version" {
  type    = string
  default = "REDIS_7_2"
}

variable "connect_mode" {
  description = "DIRECT_PEERING allocates its own range. PRIVATE_SERVICE_ACCESS reuses the PSA range."
  type        = string
  default     = "PRIVATE_SERVICE_ACCESS"
}

variable "transit_encryption_mode" {
  type    = string
  default = "DISABLED"
}

variable "labels" {
  type    = map(string)
  default = {}
}
