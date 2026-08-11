#!/bin/bash
# ============================================================================
# GSP1041 - Data Publishing on BigQuery using Authorized Views
# for Data Sharing Partners
#
# Automates all 4 tasks using bq + gcloud:
#   Task 1  Create authorized views (authorized_view_a / b) in demo_dataset
#   Task 2  Authorize the views on demo_dataset
#   Task 3  Grant BigQuery Data Viewer on each view to the customer users
#   Task 4  Verify sharing from both customer projects (save view result,
#           join with customer dataset, confirm the OTHER view is denied)
#
# Usage (in the lab's Cloud Shell - the Qwiklabs student account normally has
# access to all three lab projects):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/bq-authorized-views-gsp1041
#   chmod +x solve_gsp1041.sh
#   ./solve_gsp1041.sh
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --format="value(account)" 2>/dev/null | head -1)
[ -n "$ACTIVE_ACCOUNT" ] && gcloud config set account "$ACTIVE_ACCOUNT" --quiet 2>/dev/null || true

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1041 - Authorized Views for Data Sharing Partners Solver${NC}"
echo -e "${BOLD}======================================================================${NC}"

ask() { local label="$1" def="$2"; local v; printf "${YELLOW}%s${NC} ${CYAN}[default: %s]${NC}: " "$label" "$def"; read -p "" v; echo "${v:-$def}"; }

DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null)
PARTNER_PROJECT=$(ask "Data Sharing Partner Project ID" "$DEFAULT_PROJECT")
CUST_A_PROJECT=$(ask "Customer A Project ID" "${CUST_A_PROJECT}")
CUST_B_PROJECT=$(ask "Customer B Project ID" "${CUST_B_PROJECT}")
USER_A=$(ask "Customer A username" "${USER_A}")
USER_B=$(ask "Customer B username" "${USER_B}")

DEMO_DATASET="demo_dataset"
V_A="authorized_view_a"
V_B="authorized_view_b"
CUST_A_DATASET="customer_a_dataset"
CUST_B_DATASET="customer_b_dataset"

echo -e "${CYAN}[*] Partner: $PARTNER_PROJECT | Customer A: $CUST_A_PROJECT | Customer B: $CUST_B_PROJECT${NC}"
echo -e "${CYAN}[*] Users A=$USER_A B=$USER_B${NC}"

bq_set_project() { bq --project_id="$1" "$@"; true; }

# ============================================================================
# Task 1: Create authorized views in demo_dataset
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating authorized views...${NC}"

# Ensure demo_dataset exists
bq --project_id="$PARTNER_PROJECT" mk --location=US "$DEMO_DATASET" 2>/dev/null || true

# authorized_view_a : Texas
bq --project_id="$PARTNER_PROJECT" mk \
  --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="TX" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_A" 2>/dev/null \
  || echo "  View $V_A may already exist."

# authorized_view_b : California
bq --project_id="$PARTNER_PROJECT" mk \
  --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="CA" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_B" 2>/dev/null \
  || echo "  View $V_B may already exist."

echo "  Listing views:"
bq --project_id="$PARTNER_PROJECT" ls "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null || true
echo -e "\n${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Authorize both views on demo_dataset
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Authorizing views on demo_dataset...${NC}"
# Authorized views are added as access entries (VIEW type) on the dataset.
bq update \
  --add_authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$V_A" \
  "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null \
  || bq update --authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$V_A" "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null \
  || echo "  Authorize for $V_A returned non-zero (may already be set)."

bq update \
  --add_authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$V_B" \
  "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null \
  || bq update --authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$V_B" "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null \
  || echo "  Authorize for $V_B returned non-zero (may already be set)."

# Show current dataset access (authorized views should appear)
bq --project_id="$PARTNER_PROJECT" show --format=prettyjson "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null | grep -iE 'view|access' | head -20 || true
echo -e "\n${GREEN}  ==> Task 2 DONE - check progress.${NC}"
echo -e "${YELLOW}  (If the authorize step failed, do it in the console: demo_dataset -> Share -> Authorize views.)${NC}"

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
    --quiet 2>/dev/null \
    || echo "  Binding for $user failed (may need console)."
}

if [ -n "$USER_A" ]; then grant_view "$USER_A" "$V_A"; fi
if [ -n "$USER_B" ]; then grant_view "$USER_B" "$V_B"; fi
echo -e "\n${GREEN}  ==> Task 3 DONE - check progress.${NC}"
echo -e "${YELLOW}  (If bindings failed, do it in the console: open the view -> Share -> Manage permissions -> add principal with BigQuery Data Viewer.)${NC}"

# ============================================================================
# Task 4: Verify sharing from customer projects
# ============================================================================
echo -e "\n${YELLOW}[Task 4] Verifying from Customer projects...${NC}"

verify_customer() {
  local cust_project="$1" user="$2" view="$3" cust_dataset="$4" table_name="$5" state_city_label="$6" other_view="$7"
  echo -e "\n${CYAN}--- Customer check: $cust_project / view $view ---${NC}"

  # 1) Read the shared view
  echo "  Reading shared view $view ..."
  bq --project_id="$cust_project" query --use_legacy_sql=false \
    "SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$view\` LIMIT 5" >/dev/null 2>&1 \
    && echo -e "${GREEN}  [OK] View $view readable from $cust_project.${NC}" \
    || echo -e "${RED}  [!!] View not readable - check Task 2/3 grants.${NC}"

  # 2) Save the view result as a table in the customer dataset
  bq --project_id="$cust_project" mk --location=US "$cust_dataset" 2>/dev/null || true
  bq --project_id="$cust_project" query --use_legacy_sql=false \
    --destination_table "$cust_project:$cust_dataset.$table_name" \
    "SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$view\`" >/dev/null 2>&1 \
    && echo -e "${GREEN}  [OK] Saved result to $cust_dataset.$table_name.${NC}" \
    || echo -e "${YELLOW}  Saving result table failed (run 'Save view' manually if needed).${NC}"

  # 3) Join with the customer's own dataset (customer_info)
  echo "  Running join against $cust_dataset.customer_info ..."
  bq --project_id="$cust_project" query --use_legacy_sql=false \
    "SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
     FROM \`$cust_project.$cust_dataset.customer_info\` as cust
     JOIN \`$PARTNER_PROJECT.$DEMO_DATASET.$view\` as geos
     ON geos.zip_code = cust.postal_code
     LIMIT 5" 2>/dev/null \
    && echo -e "${GREEN}  [OK] Join query ran.${NC}" \
    || echo -e "${YELLOW}  Join returned nothing/error - the customer_info table may live in the lab's pre-created dataset; run it in the BigQuery console.${NC}"

  # 4) Confirm the OTHER view is NOT accessible
  echo "  Expecting Access Denied for $other_view ..."
  if bq --project_id="$cust_project" query --use_legacy_sql=false \
      "SELECT * FROM \`$PARTNER_PROJECT.$DEMO_DATASET.$other_view\` LIMIT 1" >/dev/null 2>&1; then
    echo -e "${YELLOW}  [WARN] Other view was accessible - scope check. (Lab expects Access Denied.)${NC}"
  else
    echo -e "${GREEN}  [OK] Access Denied for $other_view (correct behavior).${NC}"
  fi
}

if [ -n "$CUST_A_PROJECT" ]; then
  verify_customer "$CUST_A_PROJECT" "$USER_A" "$V_A" "$CUST_A_DATASET" "customer_a_table" "TX" "$V_B"
fi
if [ -n "$CUST_B_PROJECT" ]; then
  verify_customer "$CUST_B_PROJECT" "$USER_B" "$V_B" "$CUST_B_DATASET" "customer_b_table" "CA" "$V_A"
fi

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1041 SOLVER FINISHED - click 'Check my progress' for all 4 tasks.${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${YELLOW}Note: If the Qwiklabs account cannot reach all 3 projects, run the verify block${NC}"
echo -e "${YELLOW}inside each customer's own BigQuery console (login with that customer's credentials).${NC}"