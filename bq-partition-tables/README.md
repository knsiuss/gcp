# Creating Date-Partitioned Tables in BigQuery (GSP414)

Automated script for GSP414. This script automatically creates the `ecommerce` dataset, builds the `partition_by_day` date-partitioned table, and sets up the auto-expiring `days_with_rain` table partitioned on date.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-partition-tables
chmod +x solve_partition.sh
./solve_partition.sh
```

3. The script will execute all tasks. Once done, you can click all "Check my progress" buttons to get **100/100**!
