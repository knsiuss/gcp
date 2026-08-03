#!/bin/bash
# ============================================================================
# GSP351 - HARDCORED fix script for the CURRENT lab session.
# Values are fixed for THIS session:
#   Project : auto-detected from Cloud Shell
#   Region  : us-east1     Zone: us-east1-d
#   Source  : tst-fin-2rv (external IP 35.243.219.241)
#   One-time target   : mysql-fin-2rv        (job: mysql-fin-2rv)
#   Continuous target : mysql-fin-2rv-cont   (job: mysql-fin-2rv-cont)
#   Credentials: admin/changeme (source), root/supersecret! (Cloud SQL)
# ============================================================================
set -e

REGION="us-east1"
ZONE="us-east1-d"
SOURCE_VM="tst-fin-2rv"
SOURCE_IP="35.243.219.241"
DST1="mysql-fin-2rv"
DST2="mysql-fin-2rv-cont"
PROJECT_ID=$(gcloud config get-value project)

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${BOLD}GSP351 hardcoded fix (${REGION}/${ZONE})${NC}"
echo -e "${CYAN}Project: $PROJECT_ID${NC}"

job_state() { gcloud database-migration migration-jobs describe "$1" --region="$REGION" --format='value(state)' 2>/dev/null || echo "NONE"; }

wait_state() {
  local job="$1" target="$2" loops="${3:-40}" state="PENDING" i
  for i in $(seq 1 "$loops"); do
    state=$(job_state "$job")
    printf '  [%s/%s] %-22s %s\n' "$i" "$loops" "$job" "$state"
    [ "$state" == "$target" ] && { echo -e "${GREEN}  [OK] $job -> $state${NC}"; return 0; }
    case "$state" in FAILED|ABORTED) echo -e "${RED}  [!!] $job FAILED (state=$state)${NC}"; return 1;; esac
    sleep 15
  done
  echo -e "${RED}  [TIMEOUT] $job last state: $state${NC}"
  return 1
}

# ============================================================================
# Task 3 (critical): make the continuous job RUNNING
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Starting continuous job $DST2 ...${NC}"
echo "  Current state: $(job_state "$DST2")"

if [ "$(job_state "$DST2")" != "RUNNING" ]; then
  echo "  Demoting destination (best-effort)..."
  gcloud database-migration migration-jobs demote-destination "$DST2" --region="$REGION" --quiet 2>/dev/null \
    && sleep 20 || echo "  Demote skipped/already done."

  echo "  Starting job..."
  gcloud database-migration migration-jobs start "$DST2" --region="$REGION" --quiet 2>/dev/null \
    || echo "  Start returned non-zero; checking state."

  wait_state "$DST2" "RUNNING" 60 || echo -e "${YELLOW}  Not RUNNING yet.${NC}"
fi

# ============================================================================
# Verify one-time migration (Task 2): 5030 rows on $DST1
# ============================================================================
echo -e "\n${YELLOW}[Task 2 verify] 5030 rows on $DST1 ...${NC}"
gcloud sql instances patch "$DST1" --authorized-networks="$(curl -s ifconfig.me)" --quiet 2>/dev/null || true
SQL_IP=$(gcloud sql instances describe "$DST1" --format='value(ipAddresses[0].ipAddress)' 2>/dev/null || true)
if [ -n "$SQL_IP" ] && command -v mysql >/dev/null 2>&1; then
  echo "  IP: $SQL_IP"
  COUNT=$(MYSQL_PWD='supersecret!' mysql -h "$SQL_IP" -u root -N -e "use customers_data; select count(*) from customers;" 2>/dev/null || true)
  echo "  Row count: ${COUNT:-<error>}"
  [ "$COUNT" == "5030" ] && echo -e "${GREEN}  [OK] 5030 rows confirmed.${NC}" || echo -e "${YELLOW}  Not 5030 yet.${NC}"
else
  echo -e "${YELLOW}  mysql client or SQL IP unavailable. Manual check:${NC}"
  echo '    echo "use customers_data; select count(*) from customers;" | gcloud sql connect mysql-fin-2rv --user=root'
fi

# ============================================================================
# Task 4: ensure UPDATE applied on source, then verify at destination
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Updating source + checking replication...${NC}"
echo "  Running UPDATE on $SOURCE_VM (idempotent)..."
gcloud compute ssh "$SOURCE_VM" --zone="$ZONE" --quiet \
  --ssh-flag="-o StrictHostKeyChecking=no" --ssh-flag="-o ConnectTimeout=20" \
  --command="mysql -uadmin -pchangeme -e \"use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;\"" 2>/dev/null \
  && echo -e "${GREEN}  [OK] UPDATE ran.${NC}" || echo -e "${YELLOW}  UPDATE failed; run manually.${NC}"

echo "  Waiting 60s for propagation..."
sleep 60

gcloud sql instances patch "$DST2" --authorized-networks="$(curl -s ifconfig.me)" --quiet 2>/dev/null || true
SQL_IP2=$(gcloud sql instances describe "$DST2" --format='value(ipAddresses[0].ipAddress)' 2>/dev/null || true)
if [ -n "$SQL_IP2" ] && command -v mysql >/dev/null 2>&1; then
  GENDER=$(MYSQL_PWD='supersecret!' mysql -h "$SQL_IP2" -u root -N -e "use customers_data; select gender from customers where addressKey = 934;" 2>/dev/null || true)
  echo "  gender@934 = ${GENDER:-<error>}"
  echo "$GENDER" | grep -qi 'FEMALE' && echo -e "${GREEN}  [OK] Replication works.${NC}" || echo -e "${YELLOW}  Not FEMALE yet.${NC}"
else
  echo -e "${YELLOW}  Manual check:${NC}"
  echo '    echo "use customers_data; select gender from customers where addressKey = 934;" | gcloud sql connect mysql-fin-2rv-cont --user=root'
fi

# ============================================================================
# Task 5: promote the continuous destination
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Promoting $DST2 ...${NC}"
ST=$(job_state "$DST2")
echo "  State before promote: $ST"
if [ "$ST" == "RUNNING" ] || [ "$ST" == "COMPLETED" ]; then
  gcloud database-migration migration-jobs promote "$DST2" --region="$REGION" --quiet 2>/dev/null \
    && echo -e "${GREEN}  [OK] Promote accepted.${NC}" || echo -e "${YELLOW}  Promote returned non-zero.${NC}"
else
  echo -e "${RED}  [!!] Job is $ST, not RUNNING. Cannot promote yet.${NC}"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  DONE. Check progress on Qwiklabs.${NC}"
echo -e "${GREEN}  Final state of $DST2: $(job_state "$DST2")${NC}"
echo -e "${GREEN}======================================================================${NC}"
