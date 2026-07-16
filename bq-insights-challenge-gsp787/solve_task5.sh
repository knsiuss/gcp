#!/bin/bash
# solve_task5.sh
# Automating GSP787: Derive Insights from BigQuery Data (Task 5 & Task 9)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: GSP787 Task 5 & Task 9 Queries                  ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[*] Running Task 5 BigQuery query (Identify a specific day)...${NC}"
bq query --use_legacy_sql=false '
SELECT
  date
FROM
  `bigquery-public-data.covid19_open_data.covid19_open_data`
WHERE
  country_name = "Italy"
  AND cumulative_deceased > 10000
  AND cumulative_deceased IS NOT NULL
ORDER BY
  date ASC
LIMIT 1
'

echo -e "\n${YELLOW}[*] Running Task 9 BigQuery query (CDGR France)...${NC}"
bq query --use_legacy_sql=false '
WITH france_cases AS (
  SELECT
    date,
    SUM(cumulative_confirmed) AS total_cases
  FROM
    `bigquery-public-data.covid19_open_data.covid19_open_data`
  WHERE
    country_name="France"
    AND date IN ("2020-01-24", "2020-05-25")
  GROUP BY
    date
  ORDER BY
    date)
, summary as (
SELECT
  total_cases AS first_day_cases,
  LEAD(total_cases) OVER(ORDER BY date) AS last_day_cases,
  DATE_DIFF(LEAD(date) OVER(ORDER BY date),date, day) AS days_diff
FROM
  france_cases
LIMIT 1
)
select first_day_cases, last_day_cases, days_diff, POWER((last_day_cases/first_day_cases),(1/days_diff))-1 as cdgr
from summary
'

echo -e "\n${GREEN}[+] Queries executed successfully in Cloud Shell!${NC}"
echo -e "${YELLOW}[TIP] If Qwiklabs checkpoint does not update, please copy-paste and run these queries inside the BigQuery Console UI.${NC}"
echo -e "${GREEN}======================================================================${NC}"
