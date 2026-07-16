# Detect and Investigate Threats with Security Command Center (GSP1125)

This repository contains the automation script for completing the **Detect and Investigate Threats with Security Command Center (GSP1125)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b scc-threat-detection https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_threats.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_threats.sh
   ```
   *The script will automatically detect your project ID and number, and prompt you to input the **Region** and **Zone** provided in your specific lab credentials (e.g., `us-east1` and `us-east1-d`).*

---

## What the Script Automates

1. **Task 1 (Persistence Threat)**: Grants the `BigQuery Admin` role to the external user `demouser1@gmail.com` to simulate an anomalous persistence grant, waits, and then removes the role to mitigate the threat.
2. **Task 2 (Self-Investigation Threat)**: Automatically fetches the project's IAM policy, modifies it using Python to enable `ADMIN_READ` audit logs for the `resourcemanager.googleapis.com` API, and sets it back. It then provisions a GCE VM `instance-1` with full scopes, waits for SSH capability, and executes the self-investigation command (`gcloud projects get-iam-policy`) inside the VM via SSH.
3. **Task 3 (Malware Query Threat)**: Creates a Cloud DNS Server Policy `dns-test-policy` with query logging enabled. It then executes the malware query simulator command (`curl etd-malware-trigger.goog`) inside the VM via SSH, and finally deletes the VM to clean up resources.
