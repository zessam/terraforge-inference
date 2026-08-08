variable "project_id" {
  type = string
}

variable "name" {
  description = "Name prefix for the address and certificate."
  type        = string
}

variable "domain" {
  description = "Real domain for the endpoint. Takes precedence over wildcard DNS."
  type        = string
  default     = ""
}

variable "use_wildcard_dns" {
  description = "With no real domain, derive a hostname from the reserved IP via a wildcard DNS service."
  type        = bool
  default     = true
}

variable "wildcard_dns_suffix" {
  description = "Wildcard DNS provider. nip.io and sslip.io both resolve <ip>.<suffix> to <ip>."
  type        = string
  default     = "nip.io"
}
