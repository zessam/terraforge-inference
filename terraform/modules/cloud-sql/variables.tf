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
  default = "POSTGRES_16"
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

variable "point_in_time_recovery" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  description = "Set true for anything that is not a lab."
  type        = bool
  default     = false
}
