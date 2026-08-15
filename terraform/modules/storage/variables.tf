variable "project_id" {
  type = string
}

variable "name" {
  description = "Bucket name. Globally unique across all of GCS, so prefix it."
  type        = string
}

variable "location" {
  description = "Bucket location. Keep it in the region the workload runs in; cross-region reads are charged as egress."
  type        = string
}

variable "versioning" {
  description = "Keep noncurrent versions so an accidental delete or overwrite is recoverable."
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Delete live objects older than this. 0 disables the rule. Langfuse events are raw ingestion data, not the system of record — ClickHouse is."
  type        = number
  default     = 90
}

variable "noncurrent_version_days" {
  description = "How long a superseded version survives. Only applies when versioning is on."
  type        = number
  default     = 7
}

variable "writers" {
  description = "IAM members granted roles/storage.objectAdmin on this bucket. Object-level only; nobody gets bucket admin."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
