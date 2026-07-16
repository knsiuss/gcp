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

variable "network_name" {
  description = "The VPC network name to connect the instances to"
  type        = string
  default     = "default"
}

variable "subnet_1_name" {
  description = "The subnet name for tf-instance-1"
  type        = string
  default     = ""
}

variable "subnet_2_name" {
  description = "The subnet name for tf-instance-2"
  type        = string
  default     = ""
}
