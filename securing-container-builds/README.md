# Securing Container Builds (GSP1185)

This folder contains the automation script and configurations for completing the **Securing Container Builds (GSP1185)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b securing-container-builds https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_securing_builds.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_securing_builds.sh
   ```
   *The script will automatically detect your project ID and number, and run all 4 tasks consecutively.*

---

## What the Script Automates

1. **API**: Enables the `artifactregistry.googleapis.com` service.
2. **Setup**: Clones the `java-docs-samples` Google repository and navigates to the container analysis directory.
3. **Task 1 (Standard Repo)**: Creates the standard maven repository `container-dev-java-repo` in `us-central1`.
4. **Task 2 (Configure Maven)**: Uses Python to inject distributionManagement, repositories and Wagon extension settings inside the project's `pom.xml` pointing to your GID. Then deploys the hello-world package via `mvn deploy`.
5. **Task 3 (Remote Repo)**: Creates the remote Central Cache registry `maven-central-cache` in `us-central1`, updates `pom.xml` with the cache point, creates `.mvn/extensions.xml`, and compiles the application to cache central packages.
6. **Task 4 (Virtual Repo)**: Creates the upstream policy `policy.json`, creates the virtual repository `virtual-maven-repo`, replaces `pom.xml` repositories with the virtual pointer, resets the `maven-central-cache` registry to empty, and compiles again to pull and cache dependencies via the virtual path.
