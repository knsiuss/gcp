#!/bin/bash
# solve_gsp281_task6.sh
# Automating GSP281: Introduction to SQL for BigQuery and Cloud SQL (Task 6)

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}    Automated Solver: SQL for BigQuery & Cloud SQL (GSP281 - Task 6)  ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect GCP Project details
export PROJECT_ID=$(gcloud config get-value project)
echo -e "${YELLOW}[*] Project ID:${NC} $PROJECT_ID"

# Instance ID
INSTANCE_ID="my-demo"
PASSWORD="ChangeMe1!"

echo -e "\n${YELLOW}[Step 1] Creating database 'bike' in Cloud SQL instance '$INSTANCE_ID'...${NC}"
# Wait until Cloud SQL instance is in RUNNING state
echo -e "${YELLOW}[*] Checking Cloud SQL instance status...${NC}"
while true; do
    STATUS=$(gcloud sql instances describe "$INSTANCE_ID" --format="value(state)" 2>/dev/null || echo "PENDING")
    if [ "$STATUS" = "RUNNING" ]; then
        echo -e "${GREEN}[+] Instance is running!${NC}"
        break
    else
        echo -e "${YELLOW}[*] Instance state is $STATUS. Waiting 15 seconds...${NC}"
        sleep 15
    fi
done

# Create database
gcloud sql databases create bike --instance="$INSTANCE_ID" --quiet || true

echo -e "\n${YELLOW}[Step 2] Creating tables 'london1' and 'london2'...${NC}"
# Connect and run SQL queries using stdin redirect for password and SQL commands
gcloud sql connect "$INSTANCE_ID" --user=root --quiet << EOF
$PASSWORD
USE bike;
CREATE TABLE IF NOT EXISTS london1 (start_station_name VARCHAR(255), num INT);
CREATE TABLE IF NOT EXISTS london2 (end_station_name VARCHAR(255), num INT);
SHOW TABLES;
EOF

echo -e "${GREEN}[+] Database 'bike' and tables created successfully!${NC}"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}    Task 6 Completed! Please check progress on Qwiklabs.             ${NC}"
echo -e "${GREEN}======================================================================${NC}"
