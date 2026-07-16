variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
  default     = "<PROJECT_ID>"
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
  description = "The GCS bucket name for the remote backend"
  type        = string
  default     = "<BUCKET_NAME>"
}

variable "vpc_name" {
  description = "The VPC network name"
  type        = string
  default     = "<VPC_NAME>"
}
