terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Task 3: Uncomment this backend block AFTER creating the bucket in Task 3.
  # Then run `terraform init` and type 'yes' to migrate your state to GCS.
  # backend "gcs" {
  #   bucket = "<BUCKET_NAME>"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "instances" {
  source     = "./modules/instances"
  project_id = var.project_id
  region     = var.region
  zone       = var.zone

  # Task 2: Keep commented out (will default to the 'default' network and no subnet)
  # Task 6: Uncomment these three lines below to connect instances to your new VPC subnets
  # network_name  = var.vpc_name
  # subnet_1_name = "subnet-01"
  # subnet_2_name = "subnet-02"
}

# Task 3: Storage Module to create the backend bucket
module "storage" {
  source      = "./modules/storage"
  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  bucket_name = var.bucket_name
}

# Task 6: Network Module from Terraform Registry (uncomment in Task 6)
# module "vpc" {
#   source  = "terraform-google-modules/network/google"
#   version = "10.0.0"
# 
#   project_id   = var.project_id
#   network_name = var.vpc_name
#   routing_mode = "GLOBAL"
# 
#   subnets = [
#     {
#       subnet_name   = "subnet-01"
#       subnet_ip     = "10.10.10.0/24"
#       subnet_region = var.region
#     },
#     {
#       subnet_name   = "subnet-02"
#       subnet_ip     = "10.10.20.0/24"
#       subnet_region = var.region
#     }
#   ]
# }

# Task 7: Firewall Rule (uncomment in Task 7)
# resource "google_compute_firewall" "tf-firewall" {
#   name    = "tf-firewall"
#   network = var.vpc_name # Can also reference module.vpc.network_name
# 
#   allow {
#     protocol = "tcp"
#     ports    = ["80"]
#   }
# 
#   source_ranges = ["0.0.0.0/0"]
# }
