variable "project_id" {
  type = string
}

variable "location" {
  description = "Region for the repository. Keep it with the cluster to avoid cross-region pulls."
  type        = string
}

variable "repository_id" {
  description = "Repository name."
  type        = string
}

variable "description" {
  type    = string
  default = ""
}

variable "format" {
  description = "Repository format: DOCKER, MAVEN, NPM, PYTHON, ..."
  type        = string
  default     = "DOCKER"
}

variable "readers" {
  description = "IAM members granted pull access."
  type        = list(string)
  default     = []
}

variable "writers" {
  description = "IAM members granted push access, typically CI."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
