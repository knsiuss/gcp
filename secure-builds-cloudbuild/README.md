# Secure Builds with Cloud Build (GSP1184)

Automated script for GSP1184. This script builds and pushes container images to Artifact Registry using Cloud Build, sets up On-Demand vulnerability scanning, configures a DevSecOps CI/CD pipeline step that automatically fails the build if CRITICAL vulnerabilities are found, and fixes the vulnerability by upgrading the container to use a secure Python Alpine base image.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/secure-builds-cloudbuild
chmod +x solve_secure_builds.sh
./solve_secure_builds.sh
```

3. Enter the region provided by the lab (e.g. `us-central1` or `us-east1`) when prompted.
4. The script will execute all tasks and verification steps. Once done, you can click all "Check my progress" buttons to get **100/100**!
