# Introduction to SQL for BigQuery and Cloud SQL (GSP281) - Task 6 Solver

Automated script for GSP281 Task 6. This script automates creating the `bike` database in Cloud SQL, waiting for the instance to be fully ready, connecting to the Cloud SQL database, and creating the `london1` and `london2` tables with correct schemas.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-sql-cloudsql-gsp281
chmod +x solve_gsp281_task6.sh
./solve_gsp281_task6.sh
```

3. The script will automatically verify and connect, then create the database and tables. Click the "Check my progress" button for Task 6 to get points!
