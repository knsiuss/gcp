#!/bin/bash
# solve_task5.sh
# Automating GSP787: Derive Insights from BigQuery Data (Task 5)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: GSP787 Task 5 (Identify a Specific Day)         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[*] Running Task 5 BigQuery query...${NC}"
bq query --use_legacy_sql=false '
SELECT
  date
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE
  country_name = "Italy"
  AND cumulative_deceased > 10000
ORDER BY
  date ASC
LIMIT 1
'

echo -e "${GREEN}[+] Query executed successfully! Check the progress on Qwiklabs.${NC}"
echo -e "${GREEN}======================================================================${NC}"
