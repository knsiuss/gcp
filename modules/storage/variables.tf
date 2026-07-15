variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy resources in"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "The zone to deploy resources in"
  type        = string
  default     = "europe-west1-b"
}

variable "bucket_name" {
  description = "The name of the GCS bucket to create"
  type        = string
}
