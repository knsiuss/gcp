#!/bin/bash
# solve_join_pitfalls.sh
# Automating Troubleshooting and Solving Data Join Pitfalls (GSP412)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: BigQuery Data Join Pitfalls (GSP412)            ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

echo -e "\n${YELLOW}[Step 1] Creating Dataset 'ecommerce'...${NC}"
bq mk --location=US --dataset_id="${PROJECT_ID}:ecommerce" || true

echo -e "${GREEN}[+] Dataset created! (Task 1 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 2] Running Key Field Analysis Queries...${NC}"

bq query --use_legacy_sql=false '
SELECT DISTINCT
productSKU,
v2ProductName
FROM `data-to-insights.ecommerce.all_sessions_raw`
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT
DISTINCT
productSKU
FROM `data-to-insights.ecommerce.all_sessions_raw`
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT
  v2ProductName,
  COUNT(DISTINCT productSKU) AS SKU_count,
  STRING_AGG(DISTINCT productSKU LIMIT 5) AS SKU
FROM `data-to-insights.ecommerce.all_sessions_raw`
  WHERE productSKU IS NOT NULL
  GROUP BY v2ProductName
  HAVING SKU_count > 1
  ORDER BY SKU_count DESC
  LIMIT 10'

bq query --use_legacy_sql=false '
SELECT
  productSKU,
  COUNT(DISTINCT v2ProductName) AS product_count,
  STRING_AGG(DISTINCT v2ProductName LIMIT 5) AS product_name
FROM `data-to-insights.ecommerce.all_sessions_raw`
  WHERE v2ProductName IS NOT NULL
  GROUP BY productSKU
  HAVING product_count > 1
  ORDER BY product_count DESC
  LIMIT 10'

echo -e "${GREEN}[+] Uniqueness and key field checks completed! (Task 4 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 3] Running Non-Unique Key Pitfall Queries...${NC}"

bq query --use_legacy_sql=false '
SELECT DISTINCT
  v2ProductName,
  productSKU
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE productSKU = "GGOEGPJC019099"'

bq query --use_legacy_sql=false '
SELECT
  SKU,
  name,
  stockLevel
FROM `data-to-insights.ecommerce.products`
WHERE SKU = "GGOEGPJC019099"'

bq query --use_legacy_sql=false '
SELECT DISTINCT
  website.v2ProductName,
  website.productSKU,
  inventory.stockLevel
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
JOIN `data-to-insights.ecommerce.products` AS inventory
  ON website.productSKU = inventory.SKU
  WHERE productSKU = "GGOEGPJC019099"'

bq query --use_legacy_sql=false '
WITH inventory_per_sku AS (
  SELECT DISTINCT
    website.v2ProductName,
    website.productSKU,
    inventory.stockLevel
  FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
  JOIN `data-to-insights.ecommerce.products` AS inventory
    ON website.productSKU = inventory.SKU
    WHERE productSKU = "GGOEGPJC019099"
)
SELECT
  productSKU,
  SUM(stockLevel) AS total_inventory
FROM inventory_per_sku
GROUP BY productSKU'

echo -e "${GREEN}[+] Non-unique key queries finished! (Task 5 Checkpoint)${NC}"

echo -e "\n${YELLOW}[Step 4] Running Join Pitfall Solutions & Joins...${NC}"

bq query --use_legacy_sql=false '
SELECT
  productSKU,
  ARRAY_AGG(DISTINCT v2ProductName) AS push_all_names_into_array
FROM `data-to-insights.ecommerce.all_sessions_raw`
WHERE productSKU = "GGOEGAAX0098"
GROUP BY productSKU'

bq query --use_legacy_sql=false '
SELECT DISTINCT
website.productSKU
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
JOIN `data-to-insights.ecommerce.products` AS inventory
ON website.productSKU = inventory.SKU
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
LEFT JOIN `data-to-insights.ecommerce.products` AS inventory
ON website.productSKU = inventory.SKU
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
LEFT JOIN `data-to-insights.ecommerce.products` AS inventory
ON website.productSKU = inventory.SKU
WHERE inventory.SKU IS NULL
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
RIGHT JOIN `data-to-insights.ecommerce.products` AS inventory
ON website.productSKU = inventory.SKU
WHERE website.productSKU IS NULL
LIMIT 10'

bq query --use_legacy_sql=false '
SELECT DISTINCT
website.productSKU AS website_SKU,
inventory.SKU AS inventory_SKU
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
FULL JOIN `data-to-insights.ecommerce.products` AS inventory
ON website.productSKU = inventory.SKU
WHERE website.productSKU IS NULL OR inventory.SKU IS NULL
LIMIT 10'

echo -e "\n${YELLOW}[Step 5] Creating site_wide_promotion table (CROSS JOIN test)...${NC}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE TABLE ecommerce.site_wide_promotion AS
SELECT .05 AS discount'

bq query --use_legacy_sql=false '
SELECT DISTINCT
productSKU,
v2ProductCategory,
discount
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
CROSS JOIN ecommerce.site_wide_promotion
WHERE v2ProductCategory LIKE "%Clearance%"'

bq query --use_legacy_sql=false '
INSERT INTO ecommerce.site_wide_promotion (discount)
VALUES (.04),
       (.03)'

bq query --use_legacy_sql=false '
SELECT DISTINCT
productSKU,
v2ProductCategory,
discount
FROM `data-to-insights.ecommerce.all_sessions_raw` AS website
CROSS JOIN ecommerce.site_wide_promotion
WHERE v2ProductCategory LIKE "%Clearance%"
LIMIT 10'

echo -e "${GREEN}[+] Joins and Cross Join pitfalls verified! (Task 6 Checkpoint)${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    BigQuery Data Join Pitfalls Lab Completed! Check Qwiklabs.        ${NC}"
echo -e "${GREEN}======================================================================${NC}"
