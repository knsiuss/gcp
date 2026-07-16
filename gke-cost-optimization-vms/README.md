# Exploring Cost-optimization for GKE Virtual Machines (GSP767)

Automated script for GSP767. This script scales your deployment, resizes the GKE cluster, creates an optimized larger machine node pool, cordons and drains the legacy nodes, provisions a regional demo cluster, deploys demo pods with Anti-Affinity rules, enables VPC Flow Logs and BigQuery sink exporting, and migrates the workload to use Pod Affinity rules to minimize cross-zonal network egress costs.

## Quick Start

1. Start the lab in Qwiklabs.
2. Wait until the initial GKE cluster provisioning is completed (approximately 5 minutes).
3. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/gke-cost-optimization-vms
chmod +x solve_cost_vms.sh
./solve_cost_vms.sh
```

4. The script will run completely automatically. Once done, all checkpoints in the Qwiklabs panel will turn green!
