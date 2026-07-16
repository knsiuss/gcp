#!/bin/bash
# solve_data_warehouse.sh
# Automating Build a Data Warehouse with BigQuery: Challenge Lab (GSP340)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: BigQuery Data Warehouse Challenge (GSP340)     ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

# Ask user for partition expiration days
if [ -z "$EXPIRATION_DAYS" ]; then
    read -p "Enter Partition Expiration Days (from Task 1, e.g. 1080 or 2175, default is 1080): " EXPIRATION_DAYS
fi

if [ -z "$EXPIRATION_DAYS" ]; then
    EXPIRATION_DAYS=1080
fi

echo -e "${YELLOW}[*] Expiration Days: $EXPIRATION_DAYS${NC}"

echo -e "\n${YELLOW}[Step 1] Creating Dataset 'covid'...${NC}"
bq mk --location=US --dataset_id="${PROJECT_ID}:covid" || true

echo -e "\n${YELLOW}[Step 2] Task 1: Creating partitioned oxford_policy_tracker table...${NC}"
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE covid.oxford_policy_tracker
PARTITION BY date
OPTIONS(
  partition_expiration_days=$EXPIRATION_DAYS,
  description='oxford_policy_tracker table'
) AS
SELECT *
FROM \`bigquery-public-data.covid19_govt_response.oxford_policy_tracker\`
WHERE alpha_3_code NOT IN ('GBR', 'BRA', 'CAN', 'USA')"

echo -e "${GREEN}[+] Task 1 completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 3] Task 2: Altering global_mobility_tracker_data table...${NC}"
# Determine if table is in covid_data or covid
DATASET_NAME="covid_data"
if ! bq show "${PROJECT_ID}:covid_data.global_mobility_tracker_data" >/dev/null 2>&1; then
    if bq show "${PROJECT_ID}:covid.global_mobility_tracker_data" >/dev/null 2>&1; then
        DATASET_NAME="covid"
    else
        echo -e "${RED}Warning: global_mobility_tracker_data table not found in covid_data or covid. Attempting with covid_data...${NC}"
    fi
fi

bq query --use_legacy_sql=false \
"ALTER TABLE ${DATASET_NAME}.global_mobility_tracker_data
ADD COLUMN population INT64,
ADD COLUMN country_area FLOAT64,
ADD COLUMN mobility STRUCT<
  avg_retail FLOAT64,
  avg_grocery FLOAT64,
  avg_parks FLOAT64,
  avg_transit FLOAT64,
  avg_workplace FLOAT64,
  avg_residential FLOAT64
>"

echo -e "${GREEN}[+] Task 2 completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 4] Task 3: Populating Population Data...${NC}"
bq query --use_legacy_sql=false \
"CREATE OR REPLACE TABLE ${DATASET_NAME}.pop_data_2019 AS
SELECT country_territory_code, pop_data_2019
FROM \`bigquery-public-data.covid19_ecdc.covid_19_geographic_distribution_worldwide\`
GROUP BY country_territory_code, pop_data_2019"

bq query --use_legacy_sql=false \
"UPDATE \`${DATASET_NAME}.global_mobility_tracker_data\` t0
SET t0.population = t1.pop_data_2019
FROM \`${DATASET_NAME}.pop_data_2019\` t1
WHERE t0.alpha_3_code = t1.country_territory_code"

echo -e "${GREEN}[+] Task 3 completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${YELLOW}[Step 5] Task 4: Populating Country Area, Mobility, and Cleaning Data...${NC}"
echo -e "${YELLOW}[*] Populating country_area...${NC}"
bq query --use_legacy_sql=false \
"UPDATE \`${DATASET_NAME}.global_mobility_tracker_data\` t0
SET t0.country_area = t1.country_area
FROM \`bigquery-public-data.census_bureau_international.country_names_area\` t1
WHERE t0.country_name = t1.country_name"

echo -e "${YELLOW}[*] Populating mobility data struct...${NC}"
bq query --use_legacy_sql=false \
"UPDATE \`${DATASET_NAME}.global_mobility_tracker_data\` t0
SET 
  t0.mobility.avg_retail = t1.avg_retail,
  t0.mobility.avg_grocery = t1.avg_grocery,
  t0.mobility.avg_parks = t1.avg_parks,
  t0.mobility.avg_transit = t1.avg_transit,
  t0.mobility.avg_workplace = t1.avg_workplace,
  t0.mobility.avg_residential = t1.avg_residential
FROM (
  SELECT country_region, date,
         AVG(retail_and_recreation_percent_change_from_baseline) as avg_retail,
         AVG(grocery_and_pharmacy_percent_change_from_baseline) as avg_grocery,
         AVG(parks_percent_change_from_baseline) as avg_parks,
         AVG(transit_stations_percent_change_from_baseline) as avg_transit,
         AVG(workplaces_percent_change_from_baseline) as avg_workplace,
         AVG(residential_percent_change_from_baseline) as avg_residential
  FROM \`bigquery-public-data.covid19_google_mobility.mobility_report\`
  GROUP BY country_region, date
) AS t1
WHERE t0.country_name = t1.country_region
  AND t0.date = t1.date"

echo -e "${YELLOW}[*] Cleaning NULL values...${NC}"
bq query --use_legacy_sql=false \
"DELETE FROM \`${DATASET_NAME}.global_mobility_tracker_data\` WHERE population IS NULL"

bq query --use_legacy_sql=false \
"DELETE FROM \`${DATASET_NAME}.global_mobility_tracker_data\` WHERE country_area IS NULL"

echo -e "${GREEN}[+] Task 4 completed! (Please check progress on Qwiklabs)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    BigQuery Data Warehouse Challenge Completed! Check Qwiklabs.     ${NC}"
echo -e "${GREEN}======================================================================${NC}"
