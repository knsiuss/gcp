# Troubleshooting and Solving Data Join Pitfalls (GSP412)

Automated script for GSP412. This script automates creating the `ecommerce` dataset, running key field and non-unique key analysis, testing different join types (LEFT/RIGHT/FULL/INNER), creating the `site_wide_promotion` table, and investigating CROSS JOIN behaviors.

## Quick Start

1. Start the lab in Qwiklabs.
2. Open **Cloud Shell** and run:

```bash
git clone https://github.com/knsiuss/gcp.git gcp-labs
cd gcp-labs/bq-join-pitfalls
chmod +x solve_join_pitfalls.sh
./solve_join_pitfalls.sh
```

3. The script will execute all tasks. Once done, you can click all "Check my progress" buttons to get **100/100**!
