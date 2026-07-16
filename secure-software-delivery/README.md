# Secure Software Delivery: Challenge Lab (GSP521)

This folder contains the automation script and configurations for completing the **Secure Software Delivery: Challenge Lab (GSP521)**.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b secure-software-delivery https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_delivery.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_delivery.sh
   ```
   *The script will automatically detect your project ID and number, and prompt you to input the **Region** provided in your specific lab credentials (e.g., `us-east1`).*

---

## What the Script Automates

1. **APIs**: Enables the necessary services (`kms`, `run`, `build`, `gke`, `artifactregistry`, `ondemandscanning`, `binaryauthorization`).
2. **Setup**: Downloads the sample application source code.
3. **Task 1 (Registries)**: Creates two Artifact Registry repositories: `artifact-scanning-repo` and `artifact-prod-repo`.
4. **Task 2 (Basic Build)**: Automatically configs the basic `cloudbuild.yaml` build and push steps, and triggers a build.
5. **Task 3 (Binary Authorization)**: Configures the Container Analysis note `vulnerability_note`, creates the attestor `vulnerability-attestor`, binds occurrences viewer access, sets up KMS keyring `binauthz-keys` & `lab-key` (version 1), registers key with attestor, and enforces attestation in the default policy.
6. **Task 4 (Vulnerability Scanning CI/CD)**: Binds security roles, installs the custom community attestation builder, generates the final `cloudbuild.yaml` with all variables solved, and triggers a build. The build fails due to critical vulnerabilities, completing the checkpoint.
7. **Task 5 (Fix & Redeploy)**: Replaces the Dockerfile with secure dependencies (`python:3.8-alpine`, Flask 3.0.3, Gunicorn 23.0.0, Werkzeug 3.0.4) and submits the build. The pipeline successfully builds, scans, signs, pushes to production, and deploys to Cloud Run. Finally, it binds public access policy for easy verification.
