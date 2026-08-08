terraform {
  # Partial backend configuration: the bucket is supplied at init time so it is
  # not hardcoded per environment. Terraform does not allow variables here.
  #
  #   CI:    terraform init -backend-config="bucket=$TF_STATE_BUCKET"
  #   local: terraform init -backend-config=backend.hcl
  backend "gcs" {
    prefix = "terraforge-inference/dev"
  }
}
