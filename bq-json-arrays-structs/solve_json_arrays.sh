#!/bin/bash
# solve_json_arrays.sh
# Automating Working with JSON, Arrays, and Structs in BigQuery (GSP416)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: BigQuery JSON, Arrays, & Structs (GSP416)        ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Creating Dataset 'fruit_store'...${NC}"
bq mk --location=US --dataset_id="${PROJECT_ID}:fruit_store" || true

echo -e "${YELLOW}[*] Loading fruit_details table from Cloud Storage...${NC}"
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON \
    fruit_store.fruit_details \
    gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/shopping_cart.json

echo -e "${GREEN}[+] Dataset and fruit_details table created! (Task 2 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 2] Running Array Practice queries...${NC}"
bq query --use_legacy_sql=false '
SELECT
  fullVisitorId,
  date,
  ARRAY_AGG(DISTINCT v2ProductName) AS products_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT v2ProductName)) AS distinct_products_viewed,
  ARRAY_AGG(DISTINCT pageTitle) AS pages_viewed,
  ARRAY_LENGTH(ARRAY_AGG(DISTINCT pageTitle)) AS distinct_pages_viewed
  FROM `data-to-insights.ecommerce.all_sessions`
WHERE visitId = 1501570398
GROUP BY fullVisitorId, date
ORDER BY date'

echo -e "${GREEN}[+] Array aggregation query complete! (Task 3 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 3] Running UNNEST array query...${NC}"
bq query --use_legacy_sql=false '
SELECT DISTINCT
  visitId,
  h.page.pageTitle
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`,
UNNEST(hits) AS h
WHERE visitId = 1501570398
LIMIT 10'

echo -e "${GREEN}[+] UNNEST query complete! (Task 4 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 4] Creating Dataset 'racing' and writing schema.json...${NC}"
bq mk --location=US --dataset_id="${PROJECT_ID}:racing" || true

cat << EOF > schema.json
[
    {
        "name": "race",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "participants",
        "type": "RECORD",
        "mode": "REPEATED",
        "fields": [
            {
                "name": "name",
                "type": "STRING",
                "mode": "NULLABLE"
            },
            {
                "name": "splits",
                "type": "FLOAT",
                "mode": "REPEATED"
            }
        ]
    }
]
EOF

echo -e "${YELLOW}[*] Loading race_results table with custom schema...${NC}"
bq load --source_format=NEWLINE_DELIMITED_JSON \
    racing.race_results \
    gs://spls/gsp416/data-insights-course/labs/optimizing-for-performance/race_results.json \
    schema.json

rm -f schema.json

echo -e "${GREEN}[+] Dataset and race_results table created! (Task 6 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 5] Running Struct & UNNEST query tests...${NC}"

# Task 7
bq query --use_legacy_sql=false '
SELECT COUNT(p.name) AS racer_count
FROM racing.race_results AS r, UNNEST(r.participants) AS p'

# Task 8
bq query --use_legacy_sql=false '
SELECT
  p.name,
  SUM(split_times) as total_race_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_times
WHERE p.name LIKE "R%"
GROUP BY p.name
ORDER BY total_race_time ASC'

# Task 9
bq query --use_legacy_sql=false '
SELECT
  p.name,
  split_time
FROM racing.race_results AS r
, UNNEST(r.participants) AS p
, UNNEST(p.splits) AS split_time
WHERE split_time = 23.2'

echo -e "${GREEN}[+] Struct queries completed! (Task 7, 8, 9 Checkpoints)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    BigQuery JSON, Arrays & Structs Lab Completed! Check Qwiklabs.    ${NC}"
echo -e "${GREEN}======================================================================${NC}"
