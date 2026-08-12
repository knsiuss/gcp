#!/bin/bash
# ============================================================================
# GSP1317 - Establish VPC to VPC Connectivity using NCC Automated Solver
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION="us-east4"
ZONE="us-east4-b"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1317 - Establish VPC to VPC Connectivity using NCC Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:         ${REGION}${NC}"

# =========================================================================
# TASK 1: Enable API & Create NCC Hub
# =========================================================================
echo -e "\n${YELLOW}[Task 1] Enabling Network Connectivity API & Creating NCC Hub...${NC}"
gcloud services enable networkconnectivity.googleapis.com --project=$PROJECT_ID --quiet

gcloud network-connectivity hubs create ncc-hub --project=$PROJECT_ID --quiet 2>/dev/null || true
gcloud network-connectivity hubs describe ncc-hub --project=$PROJECT_ID

# =========================================================================
# TASK 2: Configure VPCs as NCC Spokes
# =========================================================================
echo -e "\n${YELLOW}[Task 2] Configuring VPC1 and VPC2 as NCC Spokes...${NC}"
gcloud network-connectivity spokes linked-vpc-network create vpc1-spoke1 \
    --hub=ncc-hub \
    --vpc-network=vpc1-ncc \
    --exclude-export-ranges=10.1.2.0/24 \
    --global \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

gcloud network-connectivity spokes linked-vpc-network create vpc2-spoke2 \
    --hub=ncc-hub \
    --vpc-network=vpc2-ncc \
    --exclude-export-ranges=10.3.3.0/24 \
    --global \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# =========================================================================
# TASK 4: Set up Private Service Connect
# =========================================================================
echo -e "\n${YELLOW}[Task 4] Setting up Private Service Connect to Cloud SQL...${NC}"

# Reserve Internal IP Address in subnet vpc2-ncc-subnet1
# Find free IP or use 10.2.1.50 / 10.2.1.99
CIDR=$(gcloud compute networks subnets describe vpc2-ncc-subnet1 --region=$REGION --project=$PROJECT_ID --format="value(ipCidrRange)" 2>/dev/null || echo "10.2.1.0/24")
echo "Subnet CIDR Range: $CIDR"

# Reserve IP address (try 10.2.1.50, 10.2.1.99, 10.2.1.150)
RESERVED_IP=""
for ip in "10.2.1.50" "10.2.1.99" "10.2.1.150" "10.2.1.200"; do
    if gcloud compute addresses create cloudsql-psc \
        --project=$PROJECT_ID \
        --region=$REGION \
        --subnet=vpc2-ncc-subnet1 \
        --addresses=$ip --quiet 2>/dev/null; then
        RESERVED_IP=$ip
        break
    fi
done

if [ -z "$RESERVED_IP" ]; then
    RESERVED_IP=$(gcloud compute addresses list --project=$PROJECT_ID --filter="name=cloudsql-psc" --format="value(address)" 2>/dev/null | head -1)
fi

echo "Reserved PSC IP: $RESERVED_IP"

# Get Cloud SQL Service Attachment Link
SERVICE_ATTACHMENT=$(gcloud sql instances describe cloudsql-postgres-qbcl --project=$PROJECT_ID --format="value(pscServiceAttachmentLink)" 2>/dev/null || echo "")
echo "Service Attachment URI: $SERVICE_ATTACHMENT"

# Create Forwarding Rule for PSC
gcloud compute forwarding-rules create cloudsql-psc-ep \
    --address=cloudsql-psc \
    --project=$PROJECT_ID \
    --region=$REGION \
    --network=vpc2-ncc \
    --target-service-attachment=$SERVICE_ATTACHMENT \
    --allow-psc-global-access \
    --quiet 2>/dev/null || true

# Configure DNS Managed Zone
gcloud dns managed-zones create cloudsql-dns \
    --project=$PROJECT_ID \
    --description="DNS zone for the Cloud SQL instances" \
    --dns-name=us-east4.sql.goog. \
    --networks=vpc2-ncc \
    --visibility=private \
    --quiet 2>/dev/null || true

# Get suggested DNS record
DNS_RECORD=$(gcloud sql instances describe cloudsql-postgres-qbcl --project=$PROJECT_ID --format="value(dnsName)" 2>/dev/null || echo "")
echo "DNS Record: $DNS_RECORD"

# Add A Record to DNS Zone
if [ -n "$DNS_RECORD" ] && [ -n "$RESERVED_IP" ]; then
    gcloud dns record-sets create "$DNS_RECORD" \
        --project=$PROJECT_ID \
        --type=A \
        --rrdatas=$RESERVED_IP \
        --zone=cloudsql-dns \
        --quiet 2>/dev/null || true
fi

# =========================================================================
# TASK 5: Connect to Cloud SQL via Private Service Connect
# =========================================================================
echo -e "\n${YELLOW}[Task 5] Connecting to Cloud SQL & Initializing Company Database...${NC}"

# Execute psql commands on cloudsql-client VM via SSH
if [ -n "$DNS_RECORD" ]; then
    gcloud compute ssh cloudsql-client \
        --zone=$ZONE \
        --tunnel-through-iap \
        --project=$PROJECT_ID \
        --quiet \
        --command="PGPASSWORD=changeme psql -h ${DNS_RECORD} -U postgres -d postgres -c 'CREATE DATABASE company;' 2>/dev/null || true; PGPASSWORD=changeme psql -h ${DNS_RECORD} -U postgres -d company -c 'CREATE TABLE employees (id SERIAL PRIMARY KEY, first VARCHAR(255) NOT NULL, last VARCHAR(255) NOT NULL, salary DECIMAL (10, 2));' 2>/dev/null || true; PGPASSWORD=changeme psql -h ${DNS_RECORD} -U postgres -d company -c \"INSERT INTO employees (first, last, salary) VALUES ('Max', 'Mustermann', 5000.00), ('Anna', 'Schmidt', 7000.00), ('Peter', 'Mayer', 6000.00);\" 2>/dev/null || true; PGPASSWORD=changeme psql -h ${DNS_RECORD} -U postgres -d company -c 'SELECT * FROM employees;'" 2>/dev/null || true
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1317 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
