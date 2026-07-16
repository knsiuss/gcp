# Managing a GKE Multi-tenant Cluster with Namespaces (GSP766)

Automated script for GSP766. This script sets up GKE namespaces, IAM & RBAC configurations, resource quotas, GKE usage metering, and populates the cost breakdown BigQuery table on-demand to bypass Looker Studio Scheduled Query OAuth authentication prompts.

## Quick Start

1. Start the lab in Qwiklabs.
2. Wait until the GKE cluster provisioning is completed (approximately 5 minutes).
3. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/gke-multi-tenant-namespaces
chmod +x solve_namespaces.sh
./solve_namespaces.sh
```

4. The script will run completely automatically. Once done, all checkpoints in the Qwiklabs panel will turn green!

## Optional: Visualizing Data in Looker Studio (Data Studio)

To create the visual reports:
1. Open the [Looker Studio Data Sources page](https://lookerstudio.google.com/navigation/datasources).
2. Click **Create** > **Data Source**.
3. Choose **BigQuery** -> **Custom Query** -> select your Qwiklabs project.
4. Input the following query (replace `[PROJECT-ID]` with your actual Qwiklabs Project ID):
   ```sql
   SELECT * FROM `[PROJECT-ID].cluster_dataset.usage_metering_cost_breakdown`
   ```
5. Click **Connect** and then **Create Report**.
6. Customize the charts as outlined in the lab instructions to view cost breakdowns.
