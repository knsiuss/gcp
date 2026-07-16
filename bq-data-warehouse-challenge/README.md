# Build a Data Warehouse with BigQuery: Challenge Lab (GSP340)

Automated script for GSP340. This script automates creating the partitioned `oxford_policy_tracker` table in `covid` dataset, modifying the schema of `covid_data.global_mobility_tracker_data` using DDL commands, joining population and area metrics, averaging and nesting mobility details, and cleaning NULL records.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-data-warehouse-challenge
chmod +x solve_data_warehouse.sh
./solve_data_warehouse.sh
```

3. Enter the `Partition Expiration Days` when prompted (e.g. `1080` or `2175` based on GSP340 Task 1 description).

4. The script will execute all tasks. Once done, you can click all "Check my progress" buttons to get **100/100**!
