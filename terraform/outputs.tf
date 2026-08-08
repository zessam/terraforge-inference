output "litellm_endpoint" {
  description = "Base URL for the gateway. Usable immediately, no domain required."
  value       = module.load_balancer.endpoint
}

output "litellm_hostname" {
  description = "DNS name resolving to the load balancer."
  value       = module.load_balancer.hostname
}

output "litellm_ip" {
  description = "Static IP behind the hostname."
  value       = module.load_balancer.address
}

output "litellm_ip_name" {
  description = "Ingress annotation: kubernetes.io/ingress.global-static-ip-name"
  value       = module.load_balancer.address_name
}

output "litellm_certificate_name" {
  description = "Ingress annotation: ingress.gcp.kubernetes.io/pre-shared-cert"
  value       = module.load_balancer.certificate_name
}

output "cluster_name" {
  value = module.gke.name
}

output "get_credentials" {
  description = "Run this to configure kubectl."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --zone ${var.zone} --project ${var.project_id}"
}

output "sql_connection_name" {
  description = "Instance connection name, for the Auth Proxy or gcloud."
  value       = module.cloud_sql.connection_name
}

output "database_host" {
  description = "Helm values: database.writer.host"
  value       = module.cloud_sql.private_ip_address
}

output "database_user" {
  description = "Helm values: the username key of the database secret."
  value       = module.cloud_sql.user_name
}

output "database_name" {
  description = "Helm values: database.writer.dbname"
  value       = "litellm"
}

output "redis_host" {
  description = "Helm values: redis.host"
  value       = module.memorystore.host
}

output "redis_port" {
  description = "Helm values: redis.port"
  value       = module.memorystore.port
}

output "litellm_gsa_email" {
  description = "Annotate the litellm KSA with iam.gke.io/gcp-service-account = this."
  value       = module.litellm_service_account.email
}

output "registry_url" {
  description = "Image prefix for pushes and pulls."
  value       = module.artifact_registry.url
}

output "secrets_populated" {
  description = "Secrets Terraform generated and filled."
  value       = module.secrets.populated_secret_ids
}

output "secrets_to_fill" {
  description = "Secrets created empty. Add a version to each before deploying."
  value       = module.secrets.empty_secret_ids
}
