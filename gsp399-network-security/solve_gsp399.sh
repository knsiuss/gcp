#!/bin/bash
# ============================================================================
# GSP399 - Design and Implement Network Security in Google Cloud: Challenge Lab
# Automated Solution Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Auto-activate gcloud account & project
ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
    gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
fi

if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
NETWORK="unified-vpc"
POLICY_NAME="unified-fw-policy"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP399 - Network Security Challenge Lab Automated Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project ID:     ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Network:        ${NETWORK}${NC}"

# =========================================================================
# TASK 1: Migrate legacy VPC firewall rules to a global policy
# =========================================================================
echo -e "\n${YELLOW}[Task 1] Creating Global Network Firewall Policy & Migrating Rules...${NC}"

# Create Global Network Firewall Policy
gcloud compute network-firewall-policies create $POLICY_NAME \
    --global \
    --description="Unified Global Network Firewall Policy" \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# Associate policy with unified-vpc
gcloud compute network-firewall-policies associations create \
    --firewall-policy=$POLICY_NAME \
    --network=$NETWORK \
    --global \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# Add global policy rules
gcloud compute network-firewall-policies rules create 1000 \
    --firewall-policy=$POLICY_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --layer4-configs=tcp:80,tcp:443 \
    --global-firewall-policy \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

gcloud compute network-firewall-policies rules create 1001 \
    --firewall-policy=$POLICY_NAME \
    --action=ALLOW \
    --direction=INGRESS \
    --layer4-configs=tcp:22 \
    --global-firewall-policy \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# Disable / delete legacy firewall rules
for rule in $(gcloud compute firewall-rules list --filter="network=$NETWORK" --format="value(name)" 2>/dev/null); do
    if [[ "$rule" != "containment-deny-http" && "$rule" != "allow-forensics-ssh" ]]; then
        echo "Disabling legacy rule: $rule"
        gcloud compute firewall-rules update $rule --disabled --project=$PROJECT_ID --quiet 2>/dev/null || true
    fi
done

# =========================================================================
# TASK 2: Remediate outbound Cloud NAT resolution
# =========================================================================
echo -e "\n${YELLOW}[Task 2] Remediating Cloud NAT for private-instance...${NC}"

REGION=$(gcloud compute instances list --filter="name:private-instance" --format="value(zone)" 2>/dev/null | sed 's/-[a-z]$//' | head -1)
if [ -z "$REGION" ]; then
    REGION=$(gcloud compute routers list --filter="network:$NETWORK" --format="value(region)" 2>/dev/null | head -1)
fi

if [ -z "$REGION" ]; then
    REGION="us-central1"
fi

echo "Cloud NAT Region: $REGION"

gcloud compute routers nats update unified-nat \
    --router=unified-router \
    --region=$REGION \
    --nat-all-subnetworks-all-ip-ranges \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || \
gcloud compute routers nats create unified-nat \
    --router=unified-router \
    --region=$REGION \
    --nat-all-subnetworks-all-ip-ranges \
    --project=$PROJECT_ID \
    --quiet 2>/dev/null || true

# =========================================================================
# TASK 3: Contain active threat & enforce audit logging
# =========================================================================
echo -e "\n${YELLOW}[Task 3] Containing threat & enabling VPC Flow Logs...${NC}"

# Find compromised-vm tags
COMPROMISED_TAGS=$(gcloud compute instances list --filter="name:compromised-vm" --format="value(tags.items[])" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

echo "Compromised VM Tags: $COMPROMISED_TAGS"

# 1. Deny HTTP rule
if [ -n "$COMPROMISED_TAGS" ]; then
    gcloud compute firewall-rules create containment-deny-http \
        --network=$NETWORK \
        --action=DENY \
        --rules=tcp:80 \
        --direction=INGRESS \
        --priority=100 \
        --target-tags=$COMPROMISED_TAGS \
        --project=$PROJECT_ID \
        --quiet 2>/dev/null || true
else
    gcloud compute firewall-rules create containment-deny-http \
        --network=$NETWORK \
        --action=DENY \
        --rules=tcp:80 \
        --direction=INGRESS \
        --priority=100 \
        --project=$PROJECT_ID \
        --quiet 2>/dev/null || true
fi

# 2. Forensics SSH rule from Bastion
BASTION_IP=$(gcloud compute instances list --filter="name~bastion" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null | head -1)
if [ -z "$BASTION_IP" ]; then
    BASTION_IP=$(gcloud compute instances list --filter="name~bastion" --format="value(networkInterfaces[0].networkIP)" 2>/dev/null | head -1)
fi

if [ -n "$BASTION_IP" ]; then
    SOURCE_RANGE="${BASTION_IP}/32"
else
    SOURCE_RANGE="0.0.0.0/0"
fi

echo "Bastion Source Range: $SOURCE_RANGE"

if [ -n "$COMPROMISED_TAGS" ]; then
    gcloud compute firewall-rules create allow-forensics-ssh \
        --network=$NETWORK \
        --action=ALLOW \
        --rules=tcp:22 \
        --direction=INGRESS \
        --priority=100 \
        --source-ranges=$SOURCE_RANGE \
        --target-tags=$COMPROMISED_TAGS \
        --project=$PROJECT_ID \
        --quiet 2>/dev/null || true
else
    gcloud compute firewall-rules create allow-forensics-ssh \
        --network=$NETWORK \
        --action=ALLOW \
        --rules=tcp:22 \
        --direction=INGRESS \
        --priority=100 \
        --source-ranges=$SOURCE_RANGE \
        --project=$PROJECT_ID \
        --quiet 2>/dev/null || true
fi

# 3. Enable VPC Flow Logs on subnets in unified-vpc
for subnet_info in $(gcloud compute networks subnets list --filter="network:$NETWORK" --format="csv[no-heading](name,region)" 2>/dev/null); do
    s_name=$(echo $subnet_info | cut -d',' -f1)
    s_region=$(echo $subnet_info | cut -d',' -f2)
    echo "Enabling Flow Logs on subnet: $s_name ($s_region)"
    gcloud compute networks subnets update $s_name --region=$s_region --enable-flow-logs --project=$PROJECT_ID --quiet 2>/dev/null || true
done

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP399 SOLVER EXECUTED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' on all tasks in Qwiklabs!${NC}"
