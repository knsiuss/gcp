# Optimize Costs for Google Kubernetes Engine: Challenge Lab (GSP343)

Automated script for GSP343. This script automates creating the cluster, namespaces, deploying OnlineBoutique, creating the custom optimized node pool, cordoning/draining/deleting default-pool, configuring HPA/PDB, and running locust to simulate the traffic surge.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/gke-cost-optimization-challenge
chmod +x solve_optimize.sh
./solve_optimize.sh
```

3. Enter the variables prompted from your Qwiklabs page:
   - **Cluster Name** (e.g. `onlineboutique-cluster-xyz`)
   - **Zone** (e.g. `us-central1-b`)
   - **Pool Name** (e.g. `optimized-pool-xyz`)
   - **Max Replicas** (e.g. `12`)

4. The script will execute all tasks. Once done, you can click all "Check my progress" buttons to get **100/100**!
