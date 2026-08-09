variable "project_id" {
  type = string
}

variable "name" {
  description = "Name prefix for the cluster and node pool."
  type        = string
}

variable "location" {
  description = "Zone for a zonal cluster, region for a regional one. Zonal keeps the free management tier."
  type        = string
}

variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "node_service_account" {
  description = "Email of the node pool service account."
  type        = string
}

variable "master_cidr" {
  description = "CIDR for the private control plane endpoint."
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_private_endpoint" {
  description = "True hides the control plane from the internet and requires a bastion or VPN for kubectl."
  type        = bool
  default     = false
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the control plane."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "node_labels" {
  type    = map(string)
  default = {}
}

variable "resource_labels" {
  description = "Labels on the cluster itself, for cost attribution."
  type        = map(string)
  default     = {}
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "deletion_protection" {
  description = "Set true for anything that is not a lab."
  type        = bool
  default     = false
}
