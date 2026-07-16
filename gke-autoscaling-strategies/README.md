# Understanding and Combining GKE Autoscaling Strategies (GSP768)

Automated script for GSP768. This script provisions a GKE cluster with VPA enabled, deploys a PHP-Apache app and hello-server workload, sets up Horizontal Pod Autoscaling (HPA) and Vertical Pod Autoscaling (VPA), configures Cluster Autoscaler using the `optimize-utilization` profile, creates Pod Disruption Budgets (PDBs) to allow scaling down of GKE system workloads, enables Node Auto Provisioning (NAP), and configures overprovisioning using Pause Pods.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/gke-autoscaling-strategies
chmod +x solve_autoscaling.sh
./solve_autoscaling.sh
```

3. The script will execute all tasks. Once done, you can click all "Check my progress" buttons to get **100/100**!
