# Google Cloud (GCP) Arcade Labs Automation

Welcome! This repository contains automated shell scripts and configurations to solve all your Google Cloud (GCP) Arcade and Security badge labs in a single run.

Each lab is organized into its own folder. Simply open **Google Cloud Shell** in the respective lab session, clone this repository, navigate to the folder, and run the solver script.

---

## List of Labs

### 1. Build Infrastructure with Terraform on Google Cloud: Challenge Lab (GSP345)
*   **Folder**: `terraform-challenge/`
*   **Script**: `setup_lab.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd terraform-challenge
    chmod +x setup_lab.sh
    ./setup_lab.sh
    ```

### 2. Gating Deployments with Binary Authorization (GSP1183)
*   **Folder**: `binary-authorization/`
*   **Script**: `solve_binauthz.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd binary-authorization
    chmod +x solve_binauthz.sh
    ./solve_binauthz.sh
    ```
    *Input the region (e.g. `us-east1`) and zone (e.g. `us-east1-d`) when prompted.*

### 3. Securing Container Builds (GSP1185)
*   **Folder**: `securing-container-builds/`
*   **Script**: `solve_securing_builds.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd securing-container-builds
    chmod +x solve_securing_builds.sh
    ./solve_securing_builds.sh
    ```

### 4. Secure Software Delivery: Challenge Lab (GSP521)
*   **Folder**: `secure-software-delivery/`
*   **Script**: `solve_delivery.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd secure-software-delivery
    chmod +x solve_delivery.sh
    ./solve_delivery.sh
    ```
    *Input the region (e.g. `us-east1`) when prompted.*

### 5. Get Started with Security Command Center (GSP1124)
*   **Folder**: `scc-get-started/`
*   **Script**: `solve_scc.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd scc-get-started
    chmod +x solve_scc.sh
    ./solve_scc.sh
    ```

### 6. Analyze Findings with Security Command Center (GSP1164)
*   **Folder**: `scc-findings-analysis/`
*   **Script**: `solve_scc_analysis.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd scc-findings-analysis
    chmod +x solve_scc_analysis.sh
    ./solve_scc_analysis.sh
    ```
    *Input the region (e.g. `us-east1`) and zone (e.g. `us-east1-d`) when prompted.*

### 7. Detect and Investigate Threats with Security Command Center (GSP1125)
*   **Folder**: `scc-threat-detection/`
*   **Script**: `solve_threats.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd scc-threat-detection
    chmod +x solve_threats.sh
    ./solve_threats.sh
    ```
    *Input the region (e.g. `us-east1`) and zone (e.g. `us-east1-d`) when prompted.*

### 8. Mitigate Threats and Vulnerabilities with Security Command Center: Challenge Lab (GSP382)
*   **Folder**: `scc-mitigation/`
*   **Script**: `solve_mitigation.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git .
    cd scc-mitigation
    chmod +x solve_mitigation.sh
    ./solve_mitigation.sh
    ```
    *Input the region (e.g. `us-east1`) and zone (e.g. `us-east1-d`) when prompted.*

### 9. Managing a GKE Multi-tenant Cluster with Namespaces (GSP766)
*   **Folder**: `gke-multi-tenant-namespaces/`
*   **Script**: `solve_namespaces.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/gke-multi-tenant-namespaces
    chmod +x solve_namespaces.sh
    ./solve_namespaces.sh
    ```

### 10. Exploring Cost-optimization for GKE Virtual Machines (GSP767)
*   **Folder**: `gke-cost-optimization-vms/`
*   **Script**: `solve_cost_vms.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/gke-cost-optimization-vms
    chmod +x solve_cost_vms.sh
    ./solve_cost_vms.sh
    ```

### 11. Secure Builds with Cloud Build (GSP1184)
*   **Folder**: `secure-builds-cloudbuild/`
*   **Script**: `solve_secure_builds.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/secure-builds-cloudbuild
    chmod +x solve_secure_builds.sh
    ./solve_secure_builds.sh
    ```

### 12. Understanding and Combining GKE Autoscaling Strategies (GSP768)
*   **Folder**: `gke-autoscaling-strategies/`
*   **Script**: `solve_autoscaling.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/gke-autoscaling-strategies
    chmod +x solve_autoscaling.sh
    ./solve_autoscaling.sh
    ```

### 13. Optimize Costs for Google Kubernetes Engine: Challenge Lab (GSP343)
*   **Folder**: `gke-cost-optimization-challenge/`
*   **Script**: `solve_optimize.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/gke-cost-optimization-challenge
    chmod +x solve_optimize.sh
    ./solve_optimize.sh
    ```

### 14. Creating Date-Partitioned Tables in BigQuery (GSP414)
*   **Folder**: `bq-partition-tables/`
*   **Script**: `solve_partition.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/bq-partition-tables
    chmod +x solve_partition.sh
    ./solve_partition.sh
    ```

### 15. Troubleshooting and Solving Data Join Pitfalls (GSP412)
*   **Folder**: `bq-join-pitfalls/`
*   **Script**: `solve_join_pitfalls.sh`
*   **Execution**:
    ```bash
    git clone https://github.com/knsiuss/gcp.git gcp-labs
    cd gcp-labs/bq-join-pitfalls
    chmod +x solve_join_pitfalls.sh
    ./solve_join_pitfalls.sh
    ```







