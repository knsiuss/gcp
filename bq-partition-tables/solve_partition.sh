#!/bin/bash
# solve_partition.sh
# Automating Creating Date-Partitioned Tables in BigQuery (GSP414)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: BigQuery Date-Partitioned Tables (GSP414)       ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Creating Dataset 'ecommerce'...${NC}"
bq mk --location=US --dataset_id="${PROJECT_ID}:ecommerce" || true

echo -e "${GREEN}[+] Dataset created! (Task 1 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 2] Creating Partitioned Table 'ecommerce.partition_by_day'...${NC}"
bq query --use_legacy_sql=false \
'CREATE OR REPLACE TABLE ecommerce.partition_by_day
PARTITION BY date_formatted
OPTIONS(
  description="a table partitioned by date"
) AS
SELECT DISTINCT
  PARSE_DATE("%Y%m%d", date) AS date_formatted,
  fullvisitorId
FROM `data-to-insights.ecommerce.all_sessions_raw`'

echo -e "${GREEN}[+] Table partition_by_day created! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 3] Creating Auto-Expiring Partitioned Table 'ecommerce.days_with_rain'...${NC}"
bq query --use_legacy_sql=false \
'CREATE OR REPLACE TABLE ecommerce.days_with_rain
PARTITION BY date
OPTIONS (
  partition_expiration_days=730,
  description="weather stations with precipitation, partitioned by day"
) AS
SELECT
  DATE(CAST(year AS INT64), CAST(mo AS INT64), CAST(da AS INT64)) AS date,
  (SELECT ANY_VALUE(name) FROM `bigquery-public-data.noaa_gsod.stations` AS stations
   WHERE stations.usaf = stn) AS station_name,
  prcp
FROM `bigquery-public-data.noaa_gsod.gsod*` AS weather
WHERE prcp < 99.9
  AND prcp > 0
  AND _TABLE_SUFFIX >= "2018"'

echo -e "${GREEN}[+] Table days_with_rain created! (Task 5 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    BigQuery Date-Partitioned Tables Lab Completed! Check Qwiklabs.   ${NC}"
echo -e "${GREEN}======================================================================${NC}"
