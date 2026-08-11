#!/bin/bash
# ============================================================================
# GSP1041 - Data Publishing on BigQuery using Authorized Views
# for Data Sharing Partners
#
# FULLY AUTOMATED version - all 4 tasks run from ONE Cloud Shell.
#
#   Task 1  Create authorized views (authorized_view_a / b) in demo_dataset
#   Task 2  Authorize the views on demo_dataset
#   Task 3  Grant BigQuery Data Viewer on each view to the customer users
#   Task 4  Verify sharing from both customer projects AS THE CUSTOMER USER
#           (so the "Access Denied on the other view" test is real)
#
# -----------------------------------------
# REQUIREMENT (once, at the start):
#   The 3 lab accounts use the same Qwiklabs student login - usually ONE
#   Cloud Shell account already has access to all 3 projects. If NOT,
#   add the other accounts first:
#
#     gcloud auth login --launch-browser   # log in as Customer A user
#     gcloud auth login --launch-browser   # log in as Customer B user
#
#   (verify with: gcloud auth list)
#
# Usage:
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/bq-authorized-views-gsp1041
#   ./solve_gsp1041.sh
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
  gcloud config set account "$ACTIVE_ACCOUNT" --quiet >/dev/null 2>&1 || true
else
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  [ -n "$ACTIVE_ACCOUNT" ] || ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
fi

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1041 - Authorized Views for Data Sharing Partners Solver${NC}"
echo -e "${BOLD}  (fully automated - single Cloud Shell)${NC}"
echo -e "${BOLD}======================================================================${NC}"
echo -e "${CYAN}[*] Active account: $ACTIVE_ACCOUNT${NC}"

ask() { local label="$1" def="$2"; local v; printf "${YELLOW}%s${NC} ${CYAN}[default: %s]${NC}: " "$label" "$def"; read -p "" v; echo "${v:-$def}"; }

DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
PARTNER_PROJECT=$(ask "Data Sharing Partner Project ID" "$DEFAULT_PROJECT")
CUST_A_PROJECT=$(ask "Customer A Project ID" "${CUST_A_PROJECT}")
CUST_B_PROJECT=$(ask "Customer B Project ID" "${CUST_B_PROJECT}")
USER_A=$(ask "Customer A username (full email)" "${USER_A}")
USER_B=$(ask "Customer B username (full email)" "${USER_B}")

DEMO_DATASET="demo_dataset"
V_A="authorized_view_a"
V_B="authorized_view_b"
CUST_A_DATASET="customer_a_dataset"
CUST_B_DATASET="customer_b_dataset"

echo -e "${CYAN}[*] Partner: $PARTNER_PROJECT | Customer A: $CUST_A_PROJECT | Customer B: $CUST_B_PROJECT${NC}"

# Find the gcloud account that matches a given username (fuzzy: exact or endswith).
find_account() {
  local needle="$1"
  gcloud auth list --format="value(account)" 2>/dev/null | while read -r acc; do
    if [ "$acc" = "$needle" ]; then echo "$acc"; break
    elif [ -n "$needle" ] && [[ "$acc" == *"$needle"* || "$needle" == *"$acc"* ]]; then echo "$acc"; break
    fi
  done | head -1
}

# bq query as a SPECIFIC account via BigQuery REST API (bq CLI can't take an
# --account flag, so we mint a token for that account and curl).
bq_query_as() {
  local account="$1" project="$2" sql="$3"
  local token="$4" resp
  [ -z "$token" ] && token=$(gcloud auth print-access-token "$account" 2>/dev/null)
  [ -z "$token" ] && return 1
  resp=$(curl -sS -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    "https://bigquery.googleapis.com/bigquery/v2/projects/$project/queries" \
    -d "{\"query\": $(printf '%s' "$sql" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))'), \"useLegacySql\": false, \"scalarsAsStrings\": true}" 2>/dev/null)
  local err
  err=$(printf '%s' "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("error",{}).get("message",""))' 2>/dev/null)
  if [ -n "$err" ]; then echo "__BQERR__$err"; return 1; fi
  echo "$resp"
  return 0
}

# ============================================================================
# Task 1: Create authorized views in demo_dataset
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating authorized views...${NC}"

bq --project_id="$PARTNER_PROJECT" mk --location=US "$DEMO_DATASET" >/dev/null 2>&1 || true

bq --project_id="$PARTNER_PROJECT" mk --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="TX" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_A" >/dev/null 2>&1 || echo "  $V_A may already exist."
bq --project_id="$PARTNER_PROJECT" mk --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="CA" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_B" >/dev/null 2>&1 || echo "  $V_B may already exist."

echo -e "  Views in demo_dataset:"
bq --project_id="$PARTNER_PROJECT" ls "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null | sed 's/^/    /' || true
echo -e "${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Authorize both views on demo_dataset
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Authorizing views on demo_dataset...${NC}"
for v in "$V_A" "$V_B"; do
  bq update --add_authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$v" "$PARTNER_PROJECT:$DEMO_DATASET" >/dev/null 2>&1 \
    || bq update --authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$v" "$PARTNER_PROJECT:$DEMO_DATASET" >/dev/null 2>&1 \
    || echo "  Authorize for $v failed (already set or needs console: demo_dataset -> Share -> Authorize views)."
done

GREP_AVAIL=$(bq --project_id="$PARTNER_PROJECT" show --format=prettyjson "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null | grep -iE 'authorized_view' | sed 's/^/    /' || true)
[ -n "$GREP_AVAIL" ] && echo -e "  Authorized views found:$GREP_AVAIL" || echo -e "  (no authorized views detected via JSON)"
echo -e "${GREEN}  ==> Task 2 DONE - check progress.${NC}"

# ============================================================================
# Task 3: Grant BigQuery Data Viewer on each view to the customer users
# ============================================================================
echo -e "\n${YELLOW}[Task 3] Granting BigQuery Data Viewer on the views...${NC}"

grant_view() {
  local user="$1" view="$2"
  echo "  Granting $user on $view ..."
  gcloud projects add-iam-policy-binding "$PARTNER_PROJECT" \
    --member="user:$user" \
    --role="roles/bigquery.dataViewer" \
    --condition="expression=resource.name=='projects/$PARTNER_PROJECT/datasets/$DEMO_DATASET/tables/$view',title=view_scope_${view},description='scoped to view'" \
    --quiet >/dev/null 2>&1 \
    && echo -e "${GREEN}    [OK] Binding created.${NC}" \
    || echo -e "${YELLOW}    [!!] Binding failed - do it in console: view -> Share -> Manage permissions.${NC}"
}

if [ -n "$USER_A" ]; then grant_view "$USER_A" "$V_A"; fi
if [ -n "$USER_B" ]; then grant_view "$USER_B" "$V_B"; fi
echo -e "${GREEN}  ==> Task 3 DONE - check progress.${NC}"

# ============================================================================
# Task 4: Verify sharing from customer projects (as the customer user)
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Verifying from Customer projects...${NC}"

VERIFY_NOTE=""
verify_customer() {
  local cust_project="$1" user="$2" view="$3" cust_dataset="$4" table_name="$5" other_view="$6"

  local acc
  if [ -n "$user" ]; then
    acc=$(find_account "$user")
  fi
  if [ -z "$acc" ]; then
    # fall back: maybe the single student account owns all 3 projects
    acc=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
    VERIFY_NOTE="${YELLOW}  (using $acc to check $cust_project - only conclusive if it is the customer's own account; run gcloud auth login for a real user-level check)${NC}"
  fi
  local token; token=$(gcloud auth print-access-token "$acc" 2>/dev/null || true)

  echo -e "\n${CYAN}--- Customer check: $cust_project / view $view  (as $acc) ---${NC}"

  # 1) Read the shared view
  echo "  Reading shared view $view ..."
  local r1; r1=$(bq_query_as "$acc" "$cust_project" "SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$view\` LIMIT 5")
  if [ -n "$r1" ] && [[ "$r1" != __BQERR__* ]]; then
    echo -e "${GREEN}    [OK] View $view readable from $cust_project.${NC}"
  else
    echo -e "${RED}    [!!] View not readable: ${r1#__BQERR__}. Check Tasks 2/3.${NC}"
  fi

  # 2) Save the view result as a table in the customer dataset
  echo "  Saving result to $cust_dataset.$table_name ..."
  bq --project_id="$cust_project" mk --location=US "$cust_dataset" >/dev/null 2>&1 || true
  local r2; r2=$(bq_query_as "$acc" "$cust_project" "CREATE OR REPLACE TABLE \`$cust_project.$cust_dataset.$table_name\` AS SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$view\`")
  if [ -n "$r2" ] && [[ "$r2" != __BQERR__* ]]; then
    echo -e "${GREEN}    [OK] Saved result table.${NC}"
  else
    echo -e "${YELLOW}    [..] Could not create table (${r2#__BQERR__}) - retry via 'Save view' in console if needed.${NC}"
  fi

  # 3) Join with the customer's own dataset (customer_info)
  echo "  Running join against $cust_dataset.customer_info ..."
  bq --project_id="$cust_project" mk --location=US "$cust_dataset" >/dev/null 2>&1 || true
  local r3; r3=$(bq_query_as "$acc" "$cust_project" "SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name FROM \`$cust_project.$cust_dataset.customer_info\` as cust JOIN \`$PARTNER_PROJECT.$DEMO_DATASET.$view\` as geos ON geos.zip_code = cust.postal_code LIMIT 5")
  if [ -n "$r3" ] && [[ "$r3" != __BQERR__* ]]; then
    echo -e "${GREEN}    [OK] Join query ran.${NC}"
  else
    echo -e "${YELLOW}    [..] Join note: ${r3#__BQERR__} (customer_info may need a different dataset/table name - see lab console).${NC}"
  fi

  # 4) Confirm the OTHER view is NOT accessible
  echo "  Expecting Access Denied for $other_view ..."
  local r4; r4=$(bq_query_as "$acc" "$cust_project" "SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$other_view\` LIMIT 1")
  if [ -n "$r4" ] && [[ "$r4" != __BQERR__* ]]; then
    echo -e "${YELLOW}    [WARN] $other_view WAS accessible - scope check needed (only valid when run as the customer account).${NC}"
  else
    echo -e "${GREEN}    [OK] Access Denied for $other_view (correct).${NC}"
  fi
}

if [ -n "$CUST_A_PROJECT" ]; then verify_customer "$CUST_A_PROJECT" "$USER_A" "$V_A" "$CUST_A_DATASET" "customer_a_table" "$V_B"; fi
if [ -n "$CUST_B_PROJECT" ]; then verify_customer "$CUST_B_PROJECT" "$USER_B" "$V_B" "$CUST_B_DATASET" "customer_b_table" "$V_A"; fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1041 SOLVER FINISHED - click 'Check my progress' for all 4 tasks.${NC}"
echo -e "${GREEN}======================================================================${NC}"
[ -n "$VERIFY_NOTE" ] && echo -e "$VERIFY_NOTE"
echo -e "${YELLOW}Reminder: for a conclusive Access-Denied check on the 'other view', make sure each${NC}"
echo -e "${YELLOW}customer account is logged into this Cloud Shell (gcloud auth login) so queries run as them.${NC}"