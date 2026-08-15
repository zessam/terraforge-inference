output "name" {
  description = "Bucket name. Helm values: s3.bucket"
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "gs:// URL."
  value       = google_storage_bucket.this.url
}
