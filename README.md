# Gating Deployments with Binary Authorization (GSP1183)

This folder contains the automation script and configurations for completing the **Gating Deployments with Binary Authorization (GSP1183)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone https://github.com/knsiuss/gcp.git
   cd gcp/binary-authorization
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_binauthz.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_binauthz.sh
   ```
   *The script will automatically detect your project ID and number, and prompt you to input the **Region** and **Zone** provided in your specific lab credentials.*

---

## What the Script Automates

1. **APIs**: Enables the necessary services (`kms`, `build`, `gke`, `artifactregistry`, `ondemandscanning`, `binaryauthorization`).
2. **Artifact Registry**: Creates the repository `artifact-scanning-repo` and configures docker authentications.
3. **Initial Build**: Build and push sample container image using Cloud Build.
4. **Attestor Note**: Declares and creates the Container Analysis Note (`vulnz_note`) and sets IAM policy viewer permission.
5. **Attestor Registration**: Creates the `vulnz-attestor` in Binary Authorization.
6. **KMS Keys**: Automatically provisions a key ring `binauthz-keys` and key `codelab-key`, and attaches it to the attestor.
7. **GKE Cluster**: Deploys a new GKE cluster named `binauthz` with Binary Authorization evaluation enforced.
8. **Cloud Build IAM permissions**: Grants `attestorsViewer`, `signerVerifier`, `notes.attacher`, and `ondemandscanning.admin` to Cloud Build.
9. **Custom Builder Step**: Clones the Google community cloud builders, builds the `binauthz-attestation` step, and pushes it to your project.
10. **Build & Attestation**: Triggers a Cloud Build using `cloudbuild.yaml` to compile the app and sign the container image with a valid cryptographical attestation.
11. **Policy import**: Restricts deployments in GKE to only allow container images signed by your attestor (`vulnz-attestor`).
12. **Signed Deployment**: Deploys the signed image to GKE cluster using `deploy.yaml` (successfully).
13. **Unsigned Deployment**: Compiles a `:bad` unsigned image, attempts to deploy it using `deploy_bad.yaml`, and verifies GKE correctly blocks it according to the security gate.
