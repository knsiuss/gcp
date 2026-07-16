output "bucket_name" {
  description = "The name of the storage bucket"
  value       = google_storage_bucket.backend_bucket.name
}

output "bucket_url" {
  description = "The URL of the storage bucket"
  value       = google_storage_bucket.backend_bucket.url
}
