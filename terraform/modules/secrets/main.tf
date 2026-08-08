terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  # Secret names are not sensitive even though their values are. Unwrap them so
  # they can drive for_each, which rejects sensitive expressions.
  managed_names = nonsensitive(toset(keys(var.secrets)))

  # Containers created with no version. Anything reading them fails loudly
  # until a value is added by hand, which is the intent.
  placeholder_names = toset(var.placeholder_secrets)

  all_names = setunion(local.managed_names, local.placeholder_names)

  accessor_bindings = {
    for pair in setproduct(tolist(local.all_names), var.accessor_members) :
    "${pair[0]}::${pair[1]}" => {
      secret = pair[0]
      member = pair[1]
    }
  }
}

resource "google_secret_manager_secret" "this" {
  for_each = local.all_names

  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  labels = var.labels
}

# Only the managed secrets get a version. Placeholders stay empty on purpose.
resource "google_secret_manager_secret_version" "this" {
  for_each = local.managed_names

  secret      = google_secret_manager_secret.this[each.value].id
  secret_data = var.secrets[each.value]
}

# Per-secret access rather than a project-wide secretAccessor role.
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = local.accessor_bindings

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
