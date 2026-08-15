variable "project_id" {
  description = "GCP project hosting the control plane."
  type        = string
  default     = "trisec-lab"
}

variable "region" {
  description = "GCP region. Keep close to the RunPod region."
  type        = string
  default     = "europe-west8"
}

variable "zone" {
  description = "Zone for the GKE cluster. Zonal keeps it in the GKE free management tier."
  type        = string
  default     = "europe-west8-a"
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "terraforge"
}

variable "env" {
  description = "Environment label."
  type        = string
  default     = "dev"
}

variable "placeholder_secrets" {
  description = "Secrets created empty because a third party issues them and Terraform cannot generate them. Prefixed with the environment name. Everything else is generated; see the secrets map in main.tf."
  type        = list(string)
  default = [
    "tailscale-authkey",
    "hf-token",
  ]
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the GKE control plane. Open by default so kubectl works from anywhere; the endpoint still requires IAM authentication."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [{
    cidr_block   = "0.0.0.0/0"
    display_name = "public-study-project"
  }]
}

variable "node_machine_type" {
  description = "Machine type for the GKE node pool. No GPUs here; models live on RunPod."
  type        = string
  default     = "e2-standard-4"
}

variable "node_count" {
  description = "Number of nodes in the pool."
  type        = number
  default     = 2
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-g1-small"
}

variable "redis_tier" {
  description = "BASIC is a single node. STANDARD_HA adds a replica and roughly doubles the cost."
  type        = string
  default     = "BASIC"
}

variable "redis_memory_gb" {
  description = "Memorystore size. LiteLLM uses Redis for rate-limit counters and router state, so 1GB is ample."
  type        = number
  default     = 1
}

variable "litellm_namespace" {
  description = "Kubernetes namespace LiteLLM runs in, for the Workload Identity binding."
  type        = string
  default     = "llm-system"
}

variable "litellm_ksa" {
  description = "Kubernetes service account LiteLLM runs as."
  type        = string
  default     = "litellm"
}

variable "observability_namespace" {
  description = "Kubernetes namespace the observability stack runs in, for Langfuse's Workload Identity binding."
  type        = string
  default     = "observability"
}

