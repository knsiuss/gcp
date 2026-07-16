#!/bin/bash
# GSP514: Build a Data Mesh with Knowledge Catalog: Challenge Lab
set -e

# Color codes for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   GSP514 Automation Script by Antigravity      ${NC}"
echo -e "${CYAN}================================================${NC}"

# Read User 2's email
read -p "Enter User 2's Email (from Qwiklabs panel): " USER_2
if [ -z "$USER_2" ]; then
  echo -e "${RED}User 2 Email is required!${NC}"
  exit 1
fi

python3 solve_all.py "$USER_2"
