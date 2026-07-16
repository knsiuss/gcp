# Get Started with Security Command Center (GSP1124)

This repository contains the automation script for completing the **Get Started with Security Command Center (GSP1124)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b scc-get-started https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_scc.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_scc.sh
   ```

---

## What the Script Automates

1. **Task 2 (Mute Rule)**: Creates the project-level dynamic mute rule `mute-flowlogs-findings` to mute all existing and future findings matching `category="FLOW_LOGS_DISABLED"`.
2. **Task 3 (Create Network)**: Provisions a new auto-subnet VPC network named `scc-lab-net`.
3. **Task 3 (Update Firewall)**: Finds and updates the default network's firewall rules `default-allow-rdp` and `default-allow-ssh` to restrict their ingress IP ranges from `0.0.0.0/0` to Identity Aware Proxy's secure TCP forwarding range `35.235.240.0/20`, thereby remediating the high-severity open RDP/SSH port vulnerabilities.
