# Manage Kubernetes in Google Cloud: Challenge Lab (GSP510) - Task 6 Solver

Automated script for GSP510 Task 6. This script automates modifying the `hello-app/main.go` source file to Version 2.0.0, configuring Docker authentication, building and tagging the container image as `v2` for Artifact Registry, pushing the image, updating the image path on GKE's `helloweb` deployment, and exposing the deployment as a LoadBalancer service on port 8080.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/gke-manage-kubernetes-gsp510
chmod +x solve_gsp510.sh
./solve_gsp510.sh
```

3. Enter the `Service Name` when prompted (from Task 6, e.g. `helloweb-service-epim`).

4. Once the script completes and the LoadBalancer service external IP propagates, you can click the "Check my progress" button for Task 6 to get **100/100**!
