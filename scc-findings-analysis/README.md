# Analyze Findings with Security Command Center (GSP1164)

This repository contains the automation script for completing the **Analyze Findings with Security Command Center (GSP1164)** lab.

## Automated Execution

To complete the entire lab automatically in Google Cloud Shell:

1. Clone your repository in Google Cloud Shell:
   ```bash
   git clone -b scc-findings-analysis https://github.com/knsiuss/gcp.git .
   ```
2. Make the script executable:
   ```bash
   chmod +x solve_scc_analysis.sh
   ```
3. Run the automated script:
   ```bash
   ./solve_scc_analysis.sh
   ```
   *The script will automatically detect your project ID and number, and prompt you to input the **Region** and **Zone** provided in your specific lab credentials (e.g., `us-east1` and `us-east1-d`).*

---

## What the Script Automates

1. **Task 1 (Pub/Sub Export)**: Creates the topic `export-findings-pubsub-topic`, subscription `export-findings-pubsub-topic-sub`, and establishes the project-level continuous export `export-findings-pubsub`. It then launches `instance-1` to trigger vulnerability findings and pulls/acknowledges the generated messages.
2. **Task 2 (BigQuery Export)**: Creates the BigQuery dataset `continuous_export_dataset` in your region, sets up the continuous export configuration `scc-bq-cont-export`, and creates 3 test service accounts and keys to trigger BigQuery anomalies.
3. **Task 3 (GCS Export & BQ Load)**: Creates the bucket `scc-export-bucket-PROJECT_ID`, fetches existing findings via CLI, translates them from standard JSON to JSONL matching the schema, uploads to GCS, and imports the JSONL data into BigQuery as a native table `old_findings` containing the parsed `resource` and `finding` JSON objects.
