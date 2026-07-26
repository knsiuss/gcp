#!/bin/bash
# ============================================================================
# GSP528 - Connecting Cloud Networks with NCC: Challenge Lab
# Automated Solution Script
# ============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
HUB_NAME="ncc-hub"

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP528 - Connecting Cloud Networks with NCC Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Project ID: ${PROJECT_ID}${NC}"

# Detect Region from VPN tunnels
REGION=$(gcloud compute vpn-tunnels list --format="value(region)" 2>/dev/null | head -1)

if [ -z "$REGION" ]; then
    REGION="us-central1"
fi
echo -e "${CYAN}[*] Region: ${REGION}${NC}"

# Enable Network Connectivity API
echo -e "\n${YELLOW}[Step 1] Enabling Network Connectivity API...${NC}"
gcloud services enable networkconnectivity.googleapis.com --quiet

# Task 1: Create Hub & On-Prem VPN Spokes
echo -e "\n${YELLOW}[Task 1] Creating Network Connectivity Center Hub '${HUB_NAME}'...${NC}"
gcloud network-connectivity hubs describe $HUB_NAME --project=$PROJECT_ID 2>/dev/null || \
gcloud network-connectivity hubs create $HUB_NAME \
    --project=$PROJECT_ID \
    --description="Global NCC Hub" \
    --quiet

OFFICE1_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office1'" --format="value(name)")
OFFICE2_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office2'" --format="value(name)")

echo -e "${YELLOW}[Task 1] Creating spokes for Office 1 VPN tunnels...${NC}"
i=1
while read -r tunnel_name; do
  if [ -n "$tunnel_name" ]; then
    tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
    spoke_name="office-1-spoke-$i"
    echo "Creating spoke $spoke_name for tunnel $tunnel_name..."
    gcloud alpha network-connectivity spokes create $spoke_name \
      --project=$PROJECT_ID \
      --hub=$HUB_NAME \
      --region=$REGION \
      --vpn-tunnel=$tunnel_full \
      --description="Spoke for On-Prem Office 1 tunnel $i" --quiet 2>/dev/null || true
    ((i++))
  fi
done <<< "$OFFICE1_TUNNELS"

echo -e "${YELLOW}[Task 1] Creating spokes for Office 2 VPN tunnels...${NC}"
i=1
while read -r tunnel_name; do
  if [ -n "$tunnel_name" ]; then
    tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
    spoke_name="office-2-spoke-$i"
    echo "Creating spoke $spoke_name for tunnel $tunnel_name..."
    gcloud alpha network-connectivity spokes create $spoke_name \
      --project=$PROJECT_ID \
      --hub=$HUB_NAME \
      --region=$REGION \
      --vpn-tunnel=$tunnel_full \
      --description="Spoke for On-Prem Office 2 tunnel $i" --quiet 2>/dev/null || true
    ((i++))
  fi
done <<< "$OFFICE2_TUNNELS"

# Task 2: Connect VPC to VPC
WORKLOAD_VPC1="workload-vpc-1"
WORKLOAD_VPC2="workload-vpc-2"

echo -e "\n${YELLOW}[Task 2] Creating Workload VPC Spokes...${NC}"
gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke \
  --project=$PROJECT_ID \
  --hub=$HUB_NAME \
  --vpc-network=$WORKLOAD_VPC1 \
  --global \
  --description="Spoke for Workload VPC 1" --quiet 2>/dev/null || true

gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke \
  --project=$PROJECT_ID \
  --hub=$HUB_NAME \
  --vpc-network=$WORKLOAD_VPC2 \
  --global \
  --description="Spoke for Workload VPC 2" --quiet 2>/dev/null || true

# Task 3: Connect VPC to On-prem (Spokes must contain 'hybrid')
echo -e "\n${YELLOW}[Task 3] Creating Hybrid Spokes for Workload VPC 1 & Office 1...${NC}"
gcloud network-connectivity spokes linked-vpc-network create hybrid-workload-1-spoke \
  --project=$PROJECT_ID \
  --hub=$HUB_NAME \
  --vpc-network=$WORKLOAD_VPC1 \
  --global \
  --description="Hybrid spoke for Workload VPC 1" --quiet 2>/dev/null || true

i=1
while read -r tunnel_name; do
  if [ -n "$tunnel_name" ]; then
    tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
    spoke_name="hybrid-office-1-spoke-$i"
    echo "Creating hybrid spoke $spoke_name for tunnel $tunnel_name..."
    gcloud alpha network-connectivity spokes create $spoke_name \
      --project=$PROJECT_ID \
      --hub=$HUB_NAME \
      --region=$REGION \
      --vpn-tunnel=$tunnel_full \
      --description="Hybrid spoke for On-Prem Office 1 tunnel $i" --quiet 2>/dev/null || true
    ((i++))
  fi
done <<< "$OFFICE1_TUNNELS"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP528 LAB COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Now click 'Check my progress' for all tasks on Qwiklabs!${NC}"
