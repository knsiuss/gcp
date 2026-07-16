resource "google_compute_instance" "tf-instance-1" {
  name         = "tf-instance-1"
  # Task 2: Set to "e2-micro" initially during import.
  # Task 4: Modify to "e2-standard-2"
  machine_type = "e2-micro"
  zone         = "us-east1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_1_name != "" ? var.subnet_1_name : null
  }

  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT

  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  name         = "tf-instance-2"
  # Task 2: Set to "e2-micro" initially during import.
  # Task 4: Modify to "e2-standard-2"
  machine_type = "e2-micro"
  zone         = "us-east1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_2_name != "" ? var.subnet_2_name : null
  }

  metadata_startup_script = <<-EOT
        #!/bin/bash
    EOT

  allow_stopping_for_update = true
}

# Task 4: Add third instance (Uncomment this resource for Task 4, then comment it out or delete it for Task 5)
# resource "google_compute_instance" "tf-instance-3" {
#   name         = "<INSTANCE_3_NAME>"
#   machine_type = "e2-standard-2"
#   zone         = var.zone
# 
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-11"
#     }
#   }
# 
#   network_interface {
#     network = "default"
#   }
# 
#   metadata_startup_script = <<-EOT
#         #!/bin/bash
#     EOT
# 
#   allow_stopping_for_update = true
# }
