#!/bin/bash

# setup_lab.sh
# This script configures the Terraform files with your specific Google Cloud Challenge Lab resource IDs.

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        Google Cloud Terraform Challenge Lab (GSP345) Setup          ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Detect Project ID from Cloud Shell environment
DEFAULT_PROJECT=$DEVSHELL_PROJECT_ID
if [ -z "$DEFAULT_PROJECT" ]; then
    DEFAULT_PROJECT=$GOOGLE_CLOUD_PROJECT
fi

if [ -n "$DEFAULT_PROJECT" ]; then
    read -p "Enter Google Cloud Project ID [Default: $DEFAULT_PROJECT]: " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-$DEFAULT_PROJECT}
else
    read -p "Enter Google Cloud Project ID: " PROJECT_ID
fi

# Ask for the other randomized lab resource names
read -p "Enter GCS Bucket Name (e.g., tf-bucket-278344): " BUCKET_NAME
read -p "Enter VPC Network Name (e.g., tf-vpc-179437): " VPC_NAME
read -p "Enter Third Instance Name (e.g., tf-instance-018623): " INSTANCE_3_NAME

# Basic validation
if [ -z "$PROJECT_ID" ] || [ -z "$BUCKET_NAME" ] || [ -z "$VPC_NAME" ] || [ -z "$INSTANCE_3_NAME" ]; then
    echo -e "${RED}Error: All inputs are required to properly configure the files.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[*] Updating placeholders in configuration files...${NC}"

# Replace placeholders in variables.tf
sed -i "s/<PROJECT_ID>/$PROJECT_ID/g" variables.tf
sed -i "s/<BUCKET_NAME>/$BUCKET_NAME/g" variables.tf
sed -i "s/<VPC_NAME>/$VPC_NAME/g" variables.tf

# Replace placeholders in main.tf
sed -i "s/<BUCKET_NAME>/$BUCKET_NAME/g" main.tf
sed -i "s/<VPC_NAME>/$VPC_NAME/g" main.tf

# Replace placeholders in modules/instances/instances.tf
sed -i "s/<INSTANCE_3_NAME>/$INSTANCE_3_NAME/g" modules/instances/instances.tf

echo -e "${GREEN}[+] Replacement complete! Your configuration files are now tailored for your lab session.${NC}\n"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}                        QUICK START COMMANDS                         ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "${YELLOW}Task 1:${NC} Run: ${GREEN}terraform init${NC}"
echo -e "${YELLOW}Task 2:${NC} Run the following import commands:"
echo -e "        ${GREEN}terraform import module.instances.google_compute_instance.tf-instance-1 projects/$PROJECT_ID/zones/europe-west1-b/instances/tf-instance-1${NC}"
echo -e "        ${GREEN}terraform import module.instances.google_compute_instance.tf-instance-2 projects/$PROJECT_ID/zones/europe-west1-b/instances/tf-instance-2${NC}"
echo -e "        Then run: ${GREEN}terraform apply -auto-approve${NC}"
echo -e "${YELLOW}Task 3:${NC} Run: ${GREEN}terraform apply -auto-approve${NC} (to create GCS bucket)"
echo -e "        Uncomment the ${YELLOW}backend \"gcs\"${NC} block in ${YELLOW}main.tf${NC}."
echo -e "        Then migrate the state by running: ${GREEN}terraform init -migrate-state${NC} (type 'yes' when prompted)"
echo -e "${YELLOW}Task 4:${NC} Update machine types to ${YELLOW}e2-standard-2${NC} for instances 1 and 2, and"
echo -e "        uncomment the third instance in ${YELLOW}modules/instances/instances.tf${NC}."
echo -e "        Then run: ${GREEN}terraform apply -auto-approve${NC}"
echo -e "${YELLOW}Task 5:${NC} Comment out/delete the third instance in ${YELLOW}modules/instances/instances.tf${NC}."
echo -e "        Then run: ${GREEN}terraform apply -auto-approve${NC}"
echo -e "${YELLOW}Task 6:${NC} Uncomment the ${YELLOW}module \"vpc\"${NC} block and subnet parameters in ${YELLOW}main.tf${NC}."
echo -e "        Then run: ${GREEN}terraform init${NC} followed by: ${GREEN}terraform apply -auto-approve${NC}"
echo -e "${YELLOW}Task 7:${NC} Uncomment the ${YELLOW}google_compute_firewall.tf-firewall${NC} resource in ${YELLOW}main.tf${NC}."
echo -e "        Then run: ${GREEN}terraform apply -auto-approve${NC}"
echo -e "${BLUE}======================================================================${NC}"
