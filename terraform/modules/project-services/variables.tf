variable "project_id" {
  description = "Project to enable services in."
  type        = string
}

variable "services" {
  description = "Google API service names to enable."
  type        = list(string)
}
