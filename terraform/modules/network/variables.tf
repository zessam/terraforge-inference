locals {
  pods_range     = "pods"
  services_range = "services"
}

variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router, and NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary node CIDR."
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods."
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for GKE services."
  type        = string
  default     = "10.8.0.0/20"
}

variable "enable_private_services_access" {
  description = "Reserve a range and peer it to Google, so Cloud SQL and Memorystore can have private IPs on this VPC."
  type        = bool
  default     = true
}

variable "psa_prefix_length" {
  description = "Size of the reserved PSA range. /16 leaves room for several managed services."
  type        = number
  default     = 16
}

variable "flow_log_sampling" {
  description = "Fraction of flows logged. Flow logs bill as Cloud Logging volume, so full capture is rarely worth it."
  type        = number
  default     = 0.5
}
