# Secure Builds with Cloud Build (GSP1184)

This folder contains the automation script and configurations for completing the **Secure Builds with Cloud Build (GSP1184)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b secure-builds https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_secure_builds.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_secure_builds.sh
   ```
   *The script will automatically detect your project ID and number, and prompt you to input the **Region** provided in your specific lab credentials (e.g., `us-east1`).*

---

## What the Script Automates

1. **APIs**: Enables the necessary services (`kms`, `build`, `gke`, `artifactregistry`, `ondemandscanning`, `binaryauthorization`).
2. **IAM Roles**: Grants `iam.serviceAccountUser` and `ondemandscanning.admin` to the Cloud Build service account.
3. **Task 1 (Build image)**: Configures the vulnerable `Dockerfile.vuln` and builds it with a basic `cloudbuild.yaml` config.
4. **Task 2 (Artifact Registry)**: Creates the `artifact-scanning-repo` registry in the correct region and pushes the container image.
5. **Task 4 (On-Demand Scanning)**: Triggers a local docker build and performs an on-demand scan via `gcloud artifacts docker images scan` to detect and list vulnerabilities.
6. **Task 5 (Failing Run)**: Configures the final `cloudbuild.yaml` check and runs it with the vulnerable image. The build fails due to critical vulnerabilities, satisfying the "Verify that the build breaks when a CRITICAL severity vulnerability is found" checkpoint.
7. **Task 5 (Successful Run)**: Automatically swaps the Dockerfile to `Dockerfile.secure` (utilizing `python:3.12-alpine` and updated libraries), and re-submits the build. The pipeline succeeds and pushes the secure `:good` image.
