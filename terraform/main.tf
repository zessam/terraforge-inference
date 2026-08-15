locals {
  name = "${var.name_prefix}-${var.env}"

  labels = {
    env     = var.env
    project = var.name_prefix
  }
}

module "project_services" {
  source = "./modules/project-services"

  project_id = var.project_id
  services = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "artifactregistry.googleapis.com",
    "servicenetworking.googleapis.com", # private IPs for Cloud SQL / Memorystore
    "redis.googleapis.com",
  ]
}

module "network" {
  source = "./modules/network"

  name   = local.name
  region = var.region

  depends_on = [module.project_services]
}

# Least privilege for nodes, instead of the default Compute Engine account.
module "node_service_account" {
  source = "./modules/service-account"

  project_id   = var.project_id
  account_id   = "${local.name}-gke-node"
  display_name = "GKE node pool"
  # Registry access is granted per-repository below, not project-wide.
  project_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]

  depends_on = [module.project_services]
}

module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = local.name
  description   = "Container images for ${local.name}"
  format        = "DOCKER"
  labels        = local.labels

  readers = [module.node_service_account.member]

  depends_on = [module.project_services]
}

module "gke" {
  source = "./modules/gke"

  project_id = var.project_id
  name       = local.name
  location   = var.zone # zonal: one free cluster per billing account

  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  node_service_account    = module.node_service_account.email
  master_authorized_cidrs = var.master_authorized_cidrs
  machine_type            = var.node_machine_type
  node_count              = var.node_count
  node_labels             = local.labels
  resource_labels         = local.labels
}

module "cloud_sql" {
  source = "./modules/cloud-sql"

  project_id = var.project_id
  name       = local.name
  region     = var.region
  tier       = var.db_tier
  databases  = ["litellm", "langfuse"]
  user_name  = "litellm"

  # Langfuse gets its own credential rather than sharing LiteLLM's: different
  # workload, different rotation, and it only ever touches its own database.
  extra_users = ["langfuse"]

  # Private IP on the cluster VPC; the Helm chart connects to it directly.
  private_network  = module.network.network_id
  enable_public_ip = false

  # module.network carries the Private Services Access peering, which must
  # exist before an instance can be given a private IP.
  depends_on = [module.project_services, module.network]
}

module "memorystore" {
  source = "./modules/memorystore"

  project_id         = var.project_id
  name               = local.name
  region             = var.region
  authorized_network = module.network.network_id
  tier               = var.redis_tier
  memory_size_gb     = var.redis_memory_gb
  labels             = local.labels

  # Shared by LiteLLM (rate-limit counters, router state) and Langfuse (its
  # ingestion queue). noeviction is required by the latter: an evicted key is a
  # dropped job, and Langfuse would lose traces silently under memory pressure.
  # It costs LiteLLM nothing, because its keys are coordination state it can
  # rebuild rather than a cache it needs trimmed.
  #
  # The two are separated by Redis database index, not by instance — LiteLLM on
  # 0, Langfuse on 1.
  redis_configs = {
    "maxmemory-policy" = "noeviction"
  }

  depends_on = [module.project_services, module.network]
}

# LiteLLM reaches Cloud SQL through the Auth Proxy sidecar, authenticating as
# this account via Workload Identity. No key file is ever created.
module "litellm_service_account" {
  source = "./modules/service-account"

  project_id    = var.project_id
  account_id    = "${local.name}-litellm"
  display_name  = "LiteLLM gateway"
  project_roles = ["roles/cloudsql.client"]

  workload_identity_users = ["${var.litellm_namespace}/${var.litellm_ksa}"]

  depends_on = [module.project_services]
}

resource "random_password" "litellm_master_key" {
  length  = 40
  special = false
}

resource "random_password" "litellm_salt_key" {
  length  = 40
  special = false
}

# Keys this project issues to itself, rather than receiving from a provider:
# LiteLLM presents them to the RunPod backends, and vLLM is started with the
# same value. Generated so nothing has to be invented by hand; overridable by
# adding a newer version to the secret, since every consumer reads "latest" and
# Terraform only owns the version it created.
resource "random_password" "vllm_api_key" {
  length  = 40
  special = false
}

resource "random_password" "embedding_api_key" {
  length  = 40
  special = false
}

# Langfuse needs three unrelated secrets, so they are generated separately
# rather than reusing one value: NEXTAUTH_SECRET signs session cookies, SALT
# hashes API keys, and ENCRYPTION_KEY encrypts stored provider credentials.
resource "random_password" "langfuse_nextauth_secret" {
  length  = 40
  special = false
}

resource "random_password" "langfuse_salt" {
  length  = 40
  special = false
}

# Must be exactly 64 hex characters (256 bits). random_password would give
# alphanumerics of the right length but the wrong alphabet, and Langfuse
# refuses to start on anything else.
resource "random_id" "langfuse_encryption_key" {
  byte_length = 32
}

# ClickHouse runs inside the cluster rather than as a managed service, because
# GCP has no managed ClickHouse. Its credential is generated here anyway, so
# every secret in the system has one origin.
resource "random_password" "langfuse_clickhouse" {
  length  = 32
  special = false
}

# Object storage for Langfuse. Every incoming event is written here before
# processing, which is what makes ingestion survive a database outage — so this
# is required, not an optimisation.
module "langfuse_storage" {
  source = "./modules/storage"

  project_id = var.project_id
  name       = "${local.name}-langfuse"
  location   = var.region
  labels     = local.labels

  writers = [module.langfuse_service_account.member]

  depends_on = [module.project_services]
}

# Langfuse authenticates to GCS as this account through Workload Identity. The
# Helm chart leaves LANGFUSE_GOOGLE_CLOUD_STORAGE_CREDENTIALS unset when no
# credential is configured, so the SDK falls back to the metadata server and no
# key file is ever created.
module "langfuse_service_account" {
  source = "./modules/service-account"

  project_id   = var.project_id
  account_id   = "${local.name}-langfuse"
  display_name = "Langfuse tracing"
  # Bucket access is granted per-bucket in the storage module, not project-wide.
  project_roles = []

  workload_identity_users = ["${var.observability_namespace}/langfuse"]

  depends_on = [module.project_services]
}

module "secrets" {
  source = "./modules/secrets"

  project_id = var.project_id

  labels = local.labels

  # Generated by Terraform. To change one, add a new version to the secret
  # rather than editing here: consumers read "latest", and Terraform keeps
  # managing only the version it created, so the two do not fight.
  #
  # The exception is the salt key. It encrypts provider credentials stored in
  # Postgres, so a new version makes every model already registered unreadable.
  secrets = {
    "${local.name}-db-password"        = module.cloud_sql.user_password
    "${local.name}-litellm-master-key" = "sk-${random_password.litellm_master_key.result}"
    "${local.name}-litellm-salt-key"   = random_password.litellm_salt_key.result

    "${local.name}-redis-password" = module.memorystore.auth_string

    # "sk-" because LiteLLM sends these as OpenAI-style bearer tokens.
    "${local.name}-vllm-api-key"      = "sk-${random_password.vllm_api_key.result}"
    "${local.name}-embedding-api-key" = "sk-${random_password.embedding_api_key.result}"

    "${local.name}-langfuse-nextauth-secret"     = random_password.langfuse_nextauth_secret.result
    "${local.name}-langfuse-salt"                = random_password.langfuse_salt.result
    "${local.name}-langfuse-encryption-key"      = random_id.langfuse_encryption_key.hex
    "${local.name}-langfuse-db-password"         = module.cloud_sql.extra_user_passwords["langfuse"]
    "${local.name}-langfuse-clickhouse-password" = random_password.langfuse_clickhouse.result
  }

  # Deliberately no composed DATABASE_URL. Interpolating the sensitive password
  # together with the instance's IP — unknown until apply — makes secret_data
  # both sensitive and unknown at plan time, which the provider rejects with
  # "inconsistent values for sensitive attribute". The chart takes the host,
  # database name, and credentials as separate values anyway; see the
  # database_host / database_user outputs.

  # Created empty, because these are issued by someone else and cannot be
  # generated: a Tailscale auth key and a Hugging Face token.
  placeholder_secrets = [for s in var.placeholder_secrets : "${local.name}-${s}"]

  # Both service accounts can read every secret here. Splitting access per
  # secret would be tighter, but the module grants per-secret bindings for the
  # whole accessor list, and neither workload runs untrusted code.
  accessor_members = [
    module.litellm_service_account.member,
    module.langfuse_service_account.member,
  ]

  depends_on = [module.project_services]
}

module "load_balancer" {
  source = "./modules/load-balancer"

  project_id          = var.project_id
  name                = "${local.name}-litellm"
  domain              = var.domain
  use_wildcard_dns    = var.use_wildcard_dns
  wildcard_dns_suffix = var.wildcard_dns_suffix

  depends_on = [module.project_services]
}

# A second address and certificate for the Langfuse UI.
#
# Not a path on the LiteLLM load balancer: two GKE Ingresses cannot share one
# global address, and the LiteLLM chart's path map ends in a catch-all to its
# own backend with no way to add routes in chart 1.96.2. Separate hostnames are
# the honest way to run two web UIs here.
module "langfuse_load_balancer" {
  count = var.expose_langfuse ? 1 : 0

  source = "./modules/load-balancer"

  project_id          = var.project_id
  name                = "${local.name}-langfuse"
  domain              = var.langfuse_domain
  use_wildcard_dns    = var.use_wildcard_dns
  wildcard_dns_suffix = var.wildcard_dns_suffix

  depends_on = [module.project_services]
}
