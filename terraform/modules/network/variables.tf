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
