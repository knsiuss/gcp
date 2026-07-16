# Terraform Google Cloud Challenge Lab (GSP345)

This repository contains the Terraform configuration files for the **Build Infrastructure with Terraform on Google Cloud: Challenge Lab (GSP345)**.

## How to Use this Repository in the Lab

### Step 1: Clone and Prepare
Once you open Google Cloud Shell, clone this repository (or copy these files into your Cloud Shell).

First, run the Terraform installation script provided by the lab to ensure Terraform is installed and persists:
```bash
cat <<'EOF' > ~/.customize_environment
# Set up HashiCorp repository and install Terraform
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
EOF
bash ~/.customize_environment
```
Verify the installation:
```bash
terraform --version
```

Next, run the setup script to configure your specific randomized lab names (Project ID, GCS Bucket Name, VPC Network Name, and Third Instance Name):
```bash
chmod +x setup_lab.sh
./setup_lab.sh
```

---

### Step 2: Task Walkthrough

#### Task 1: Create the configuration files
Initialize Terraform in the root directory:
```bash
terraform init
```

#### Task 2: Import Infrastructure
Two VM instances (`tf-instance-1` and `tf-instance-2`) already exist in Google Cloud. Import them into the instances module:
```bash
# Get your Google Cloud Project ID
PROJECT_ID=$(gcloud config get-value project)

# Import tf-instance-1
terraform import module.instances.google_compute_instance.tf-instance-1 projects/$PROJECT_ID/zones/europe-west1-b/instances/tf-instance-1

# Import tf-instance-2
terraform import module.instances.google_compute_instance.tf-instance-2 projects/$PROJECT_ID/zones/europe-west1-b/instances/tf-instance-2
```
After importing, apply the configuration to align Terraform's state:
```bash
terraform apply -auto-approve
```

#### Task 3: Configure a remote backend
1. First, create the storage bucket using Terraform:
   ```bash
   terraform apply -auto-approve
   ```
2. Once the bucket is created, open `main.tf` and **uncomment** the `backend "gcs"` block:
   ```hcl
   backend "gcs" {
     bucket = "tf-bucket-XXXXXX" # Configured automatically by setup_lab.sh
     prefix = "terraform/state"
   }
   ```
3. Initialize the backend and migrate the state:
   ```bash
   terraform init -migrate-state
   ```
   *Type `yes` when prompted to copy the state.*

#### Task 4: Modify and update infrastructure
1. Open `modules/instances/instances.tf`.
2. Change the `machine_type` of both `tf-instance-1` and `tf-instance-2` to `e2-standard-2`.
3. **Uncomment** the third instance block `google_compute_instance.tf-instance-3` (which represents your randomized `tf-instance-XXXXXX`).
4. Apply the updates:
   ```bash
   terraform apply -auto-approve
   ```

#### Task 5: Destroy resources
1. Open `modules/instances/instances.tf`.
2. **Comment out** (or delete) the third instance block `google_compute_instance.tf-instance-3` that you added in Task 4.
3. Apply the changes to destroy the instance:
   ```bash
   terraform apply -auto-approve
   ```

#### Task 6: Use a module from the Registry
1. Open `main.tf`:
   - **Uncomment** the `module "vpc"` block.
   - **Uncomment** the three subnet variable references inside the `module "instances"` block:
     ```hcl
     network_name  = var.vpc_name
     subnet_1_name = "subnet-01"
     subnet_2_name = "subnet-02"
     ```
2. Initialize the new network module and apply changes:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

#### Task 7: Configure a firewall
1. Open `main.tf`.
2. **Uncomment** the `google_compute_firewall` resource block `tf-firewall`.
3. Apply the firewall configuration:
   ```bash
   terraform apply -auto-approve
   ```

Verify that all checkpoints in the Google Cloud Console are green (100/100). Congratulations!
