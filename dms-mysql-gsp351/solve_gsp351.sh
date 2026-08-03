#!/bin/bash
# ============================================================================
# GSP351 - Migrate MySQL Data to Cloud SQL Using Database Migration Service
# Challenge Lab - Automated Solution (Target: 100/100)
#
# Tasks covered:
#   Task 1  Create DMS source connection profile (external IP of tst-fin-2rv)
#   Task 2  One-time migration   -> Cloud SQL mysql-fin-2rv
#   Task 3  Continuous migration -> Cloud SQL mysql-fin-2rv-cont (VPC peering)
#   Task 4  Test replication (UPDATE source -> verify destination)
#   Task 5  Promote continuous destination to standalone
#
# Usage (in the lab's Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/dms-mysql-gsp351
#   chmod +x solve_gsp351.sh
#   ./solve_gsp351.sh
# ============================================================================

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

# --- Auto-activate gcloud account & project --------------------------------
ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true
[ -n "$DEVSHELL_PROJECT_ID" ] && gcloud config set project "$DEVSHELL_PROJECT_ID" --quiet 2>/dev/null || true
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
[ -z "$PROJECT_ID" ] && PROJECT_ID="$DEVSHELL_PROJECT_ID"

# --- Lab-provided resources -------------------------------------------------
SOURCE_INSTANCE="tst-fin-2rv"
DST1="mysql-fin-2rv"
DST2="mysql-fin-2rv-cont"

SRC_PROFILE="source-mysql-profile"
DST1_PROFILE="dest-mysql-fin-2rv"
DST2_PROFILE="dest-mysql-fin-2rv-cont"
JOB1="$DST1"   # one-time job name (matches destination instance, as lab suggests)
JOB2="$DST2"   # continuous job name (matches destination instance)

REGION="us-east1"
ZONE="us-east1-d"

# Derive region/zone from the actual source instance when possible
ZONE_URL=$(gcloud compute instances describe "$SOURCE_INSTANCE" --zone="$ZONE" --format='value(zone)' 2>/dev/null || true)
if [ -n "$ZONE_URL" ]; then
  ZONE=$(basename "$ZONE_URL")
  REGION="${ZONE%-*}"
fi
gcloud config set compute/zone "$ZONE" --quiet 2>/dev/null || true
gcloud config set compute/region "$REGION" --quiet 2>/dev/null || true

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP351 - Migrate MySQL to Cloud SQL (DMS) Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Account: ${ACTIVE_ACCOUNT}${NC}"
echo -e "${CYAN}[*] Project: ${PROJECT_ID}${NC}"
echo -e "${CYAN}[*] Region:  ${REGION}${NC}"
echo -e "${CYAN}[*] Zone:    ${ZONE}${NC}"

# --- Discover source instance details ---------------------------------------
EXTERNAL_IP=$(gcloud compute instances describe "$SOURCE_INSTANCE" --zone="$ZONE" --format='value(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || true)
NETWORK_URL=$(gcloud compute instances describe "$SOURCE_INSTANCE" --zone="$ZONE" --format='value(networkInterfaces[0].network)' 2>/dev/null || true)
VPC_NAME=$(basename "$NETWORK_URL" 2>/dev/null || true)
[ -z "$VPC_NAME" ] && VPC_NAME="default"

echo -e "${CYAN}[*] Source instance: ${SOURCE_INSTANCE}${NC}"
echo -e "${CYAN}[*] External IP:    ${EXTERNAL_IP:-<NOT FOUND>}${NC}"
echo -e "${CYAN}[*] VPC network:    ${VPC_NAME}${NC}"
if [ -z "$EXTERNAL_IP" ]; then
  echo -e "${RED}[!] Could not determine the external IP of $SOURCE_INSTANCE. Aborting.${NC}"
  exit 1
fi

# --- Enable APIs ------------------------------------------------------------
echo -e "\n${YELLOW}[Setup] Enabling required APIs...${NC}"
gcloud services enable datamigration.googleapis.com sqladmin.googleapis.com servicenetworking.googleapis.com --quiet 2>/dev/null || true

# --- Detect the DMS CLI release track (GA preferred, then beta, then alpha) --
if gcloud database-migration --help >/dev/null 2>&1; then
  DMS="gcloud database-migration"
elif gcloud beta database-migration --help >/dev/null 2>&1; then
  DMS="gcloud beta database-migration"
else
  DMS="gcloud alpha database-migration"
fi
echo -e "${CYAN}[*] DMS command: ${DMS}${NC}"

# --- Helpers ----------------------------------------------------------------
job_state() {
  $DMS migration-jobs describe "$1" --region="$REGION" --format='value(state)' 2>/dev/null || echo "NONE"
}

wait_for_state() {
  local job="$1" target="$2" loops="$3" state="PENDING" i
  for i in $(seq 1 "$loops"); do
    state=$(job_state "$job")
    printf '  [%s/%s] %-22s state: %s\n' "$i" "$loops" "$job" "$state"
    if [ "$state" == "$target" ]; then
      echo -e "${GREEN}  [OK] $job reached state: $state${NC}"
      return 0
    fi
    if [ "$state" == "FAILED" ] || [ "$state" == "ABORTED" ]; then
      echo -e "${RED}  [!!] $job FAILED (state=$state). Inspect in the DMS console.${NC}"
      return 1
    fi
    sleep 15
  done
  echo -e "${RED}  [TIMEOUT] $job did not reach '$target' (last state: $state).${NC}"
  return 1
}

start_job() {
  local job="$1" i
  for i in $(seq 1 5); do
    if $DMS migration-jobs start "$job" --region="$REGION" --quiet 2>/dev/null; then
      echo -e "${GREEN}  [OK] Started $job${NC}"
      return 0
    fi
    echo "  retry start $job ($i/5)..."
    sleep 10
  done
  echo -e "${RED}  [!!] Failed to start $job.${NC}"
  return 1
}

ensure_mysql_client() {
  if ! command -v mysql >/dev/null 2>&1; then
    echo "  Installing mysql client..."
    sudo apt-get update -qq >/dev/null 2>&1 || true
    sudo apt-get install -y -qq default-mysql-client >/dev/null 2>&1 || true
  fi
  command -v mysql >/dev/null 2>&1
}

# Run a SQL query against a Cloud SQL instance (best-effort auth combos).
cloudsql_query() {
  local inst="$1" sql="$2" user pwd out
  for combo in "root|" "root|changeme" "admin|changeme"; do
    user="${combo%%|*}"
    pwd="${combo#*|}"
    out=$(MYSQL_PWD="$pwd" gcloud sql connect "$inst" --user="$user" --quiet <<< "$sql" 2>/dev/null || true)
    if [ -n "$out" ]; then
      echo "$out"
      return 0
    fi
  done
  return 1
}

# ============================================================================
# Task 1: Source connection profile (external IP)
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating MySQL source connection profile (external IP)...${NC}"
if $DMS connection-profiles describe "$SRC_PROFILE" --region="$REGION" >/dev/null 2>&1; then
  echo "  Connection profile '$SRC_PROFILE' already exists."
else
  $DMS connection-profiles create mysql "$SRC_PROFILE" \
    --region="$REGION" \
    --mysql-host="$EXTERNAL_IP" \
    --mysql-port=3306 \
    --mysql-username=admin \
    --mysql-password=changeme \
    --display-name="MySQL Source (external IP)" --quiet
  echo -e "${GREEN}  [OK] Created source connection profile: $SRC_PROFILE${NC}"
fi

# ============================================================================
# Task 2: One-time migration -> mysql-fin-2rv
# ============================================================================
echo -e "\n${YELLOW}[Task 2] One-time migration to $DST1...${NC}"
if $DMS connection-profiles describe "$DST1_PROFILE" --region="$REGION" >/dev/null 2>&1; then
  echo "  Destination profile '$DST1_PROFILE' already exists."
else
  if ! $DMS connection-profiles create cloudsql "$DST1_PROFILE" \
      --region="$REGION" --cloudsql-instance="$DST1" \
      --display-name="Cloud SQL dest: $DST1" --quiet; then
    $DMS connection-profiles create cloudsql "$DST1_PROFILE" \
      --region="$REGION" --cloudsql-instance="projects/$PROJECT_ID/locations/$REGION/instances/$DST1" \
      --display-name="Cloud SQL dest: $DST1" --quiet
  fi
  echo -e "${GREEN}  [OK] Created destination connection profile: $DST1_PROFILE${NC}"
fi

if $DMS migration-jobs describe "$JOB1" --region="$REGION" >/dev/null 2>&1; then
  echo "  Migration job '$JOB1' already exists."
else
  $DMS migration-jobs create "$JOB1" \
    --region="$REGION" --source="$SRC_PROFILE" --destination="$DST1_PROFILE" \
    --type=ONE_TIME --display-name="One-time migration to $DST1" --quiet
  echo -e "${GREEN}  [OK] Created one-time migration job: $JOB1${NC}"
fi

ST=$(job_state "$JOB1")
if [ "$ST" == "NONE" ] || [ "$ST" == "CREATING" ] || [ "$ST" == "STARTING" ]; then
  start_job "$JOB1" || true
else
  echo "  One-time job already in state: $ST"
fi

# ============================================================================
# Task 3: Continuous migration -> mysql-fin-2rv-cont (VPC peering)
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Continuous migration to $DST2 (VPC peering)...${NC}"
if $DMS connection-profiles describe "$DST2_PROFILE" --region="$REGION" >/dev/null 2>&1; then
  echo "  Destination profile '$DST2_PROFILE' already exists."
else
  if ! $DMS connection-profiles create cloudsql "$DST2_PROFILE" \
      --region="$REGION" --cloudsql-instance="$DST2" \
      --display-name="Cloud SQL dest: $DST2" --quiet; then
    $DMS connection-profiles create cloudsql "$DST2_PROFILE" \
      --region="$REGION" --cloudsql-instance="projects/$PROJECT_ID/locations/$REGION/instances/$DST2" \
      --display-name="Cloud SQL dest: $DST2" --quiet
  fi
  echo -e "${GREEN}  [OK] Created destination connection profile: $DST2_PROFILE${NC}"
fi

if $DMS migration-jobs describe "$JOB2" --region="$REGION" >/dev/null 2>&1; then
  echo "  Migration job '$JOB2' already exists."
else
  if $DMS migration-jobs create "$JOB2" \
      --region="$REGION" --source="$SRC_PROFILE" --destination="$DST2_PROFILE" \
      --type=CONTINUOUS --peer-vpc="$VPC_NAME" \
      --display-name="Continuous migration to $DST2" --quiet; then
    echo -e "${GREEN}  [OK] Created continuous migration job: $JOB2 (VPC peering: $VPC_NAME)${NC}"
  else
    echo -e "${RED}  [!!] Continuous job creation with --peer-vpc failed.${NC}"
    echo -e "${YELLOW}  Update gcloud first, then re-run the script: gcloud components update${NC}"
    echo -e "${YELLOW}  Or create the continuous job manually in the DMS console using VPC peering.${NC}"
  fi
fi

ST=$(job_state "$JOB2")
if [ "$ST" == "NONE" ] || [ "$ST" == "CREATING" ] || [ "$ST" == "STARTING" ]; then
  start_job "$JOB2" || true
else
  echo "  Continuous job already in state: $ST"
fi

echo "  Waiting for continuous migration job to enter RUNNING state..."
wait_for_state "$JOB2" "RUNNING" 40 || echo -e "${YELLOW}  Not RUNNING yet; continuing to check below.${NC}"

# ============================================================================
# Task 2 (cont): wait for one-time migration to complete
# ============================================================================
echo -e "\n${YELLOW}[Task 2 cont.] Waiting for one-time migration to COMPLETE...${NC}"
wait_for_state "$JOB1" "COMPLETED" 80 || echo -e "${YELLOW}  One-time migration not COMPLETED yet - re-check in the DMS console.${NC}"

# ============================================================================
# Task 2 verify: confirm 5030 rows
# ============================================================================
echo -e "\n${YELLOW}[Task 2 Verify] Confirming 5030 rows on $DST1...${NC}"
if ensure_mysql_client; then
  OUT=$(cloudsql_query "$DST1" "use customers_data; select count(*) from customers;" || true)
  echo "  Query output: ${OUT:-<none>}"
  if echo "$OUT" | grep -qE '(^|[^0-9])5030([^0-9]|$)'; then
    echo -e "${GREEN}  [OK] Data migration confirmed: 5030 rows.${NC}"
  else
    echo -e "${YELLOW}  Row count not confirmed automatically. Run manually:${NC}"
    echo '    echo "use customers_data; select count(*) from customers;" | gcloud sql connect mysql-fin-2rv --user=root'
  fi
else
  echo -e "${YELLOW}  mysql client unavailable; verify the row count manually.${NC}"
fi

# ============================================================================
# Task 4: Update source data and check replication
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Updating source DB and checking replication...${NC}"
sleep 30   # give the continuous job a moment to settle into CDC

echo "  Running UPDATE on source instance $SOURCE_INSTANCE ..."
UPDATE_DONE=""
# Primary: run the mysql command on the VM over SSH
if gcloud compute ssh "$SOURCE_INSTANCE" --zone="$ZONE" --quiet \
     --ssh-flag="-o StrictHostKeyChecking=no" --ssh-flag="-o ConnectTimeout=20" \
     --command="mysql -uadmin -pchangeme -e \"use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;\"" 2>/dev/null; then
  echo -e "${GREEN}  [OK] UPDATE executed via SSH.${NC}"
  UPDATE_DONE="OK"
else
  # Fallback: direct mysql over the public IP (needs port 3306 reachable from Cloud Shell)
  if ensure_mysql_client && mysql -h "$EXTERNAL_IP" -uadmin -pchangeme \
       -e "use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;" 2>/dev/null; then
    echo -e "${GREEN}  [OK] UPDATE executed via direct mysql connection.${NC}"
    UPDATE_DONE="OK"
  else
    echo -e "${RED}  [!!] Could not run the UPDATE automatically. Run it manually:${NC}"
    echo "    gcloud compute ssh $SOURCE_INSTANCE --zone=$ZONE --command=\"mysql -uadmin -pchangeme -e \\\"use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;\\\"\""
  fi
fi

echo "  Waiting 60s for the change to propagate..."
sleep 60

if [ -n "$UPDATE_DONE" ] && ensure_mysql_client; then
  OUT2=$(cloudsql_query "$DST2" "use customers_data; select gender from customers where addressKey = 934;" || true)
  echo "  Query output: ${OUT2:-<none>}"
  if echo "$OUT2" | grep -qi 'FEMALE'; then
    echo -e "${GREEN}  [OK] Replication confirmed: gender = FEMALE at destination.${NC}"
  else
    echo -e "${YELLOW}  FEMALE not observed yet at destination. Wait and re-check:${NC}"
    echo '    echo "use customers_data; select gender from customers where addressKey = 934;" | gcloud sql connect mysql-fin-2rv-cont --user=root'
  fi
else
  echo -e "${YELLOW}  Skipping automated destination check. Verify manually:${NC}"
  echo '    echo "use customers_data; select gender from customers where addressKey = 934;" | gcloud sql connect mysql-fin-2rv-cont --user=root'
fi

# ============================================================================
# Task 5: Promote the continuous destination to standalone
# ============================================================================
echo -e "\n${YELLOW}[Task 5] Promoting continuous migration destination to standalone...${NC}"
if $DMS migration-jobs promote "$JOB2" --region="$REGION" --quiet 2>/dev/null; then
  echo -e "${GREEN}  [OK] Promote accepted for job: $JOB2${NC}"
else
  echo -e "${YELLOW}  Promote returned non-zero (may already be promoted / still validating). Checking state...${NC}"
  echo "  $JOB2 state: $(job_state "$JOB2")"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP351 SOLVER FINISHED${NC}"
echo -e "${GREEN}  Now click 'Check my progress' for all 5 tasks on Qwiklabs.${NC}"
echo -e "${GREEN}======================================================================${NC}"
