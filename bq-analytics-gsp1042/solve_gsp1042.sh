#!/bin/bash
# ============================================================================
# GSP1042 - Analytics as a Service for Data Sharing Partners
#
#   Task 1  Create authorized views (authorized_view_a / b) in demo_dataset
#   Task 2  Authorize the views on demo_dataset
#   Task 3  Grant BigQuery Data Viewer on each view to the customer users
#   Task 4  Customer A: join view + save result table + Data Studio dashboards
#   Task 5  Customer B: join view + save result table + Data Studio dashboards
#
# Tasks 1-3 are fully scriptable. Tasks 4-5 automate everything EXCEPT the
# Data Studio (Looker Studio) report creation, which must be done in the
# browser (the script prints clean step-by-step instructions + a security
# verification checklist).
#
# Usage (in Cloud Shell):
#   git clone https://github.com/knsiuss/gcp.git gcp-labs
#   cd gcp-labs/bq-analytics-gsp1042
#   chmod +x solve_gsp1042.sh
#   ./solve_gsp1042.sh
# ============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -n "$ACTIVE_ACCOUNT" ]; then
  gcloud config set account "$ACTIVE_ACCOUNT" --quiet >/dev/null 2>&1 || true
else
  ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
fi

echo -e "${BOLD}======================================================================${NC}"
echo -e "${BOLD}  GSP1042 - Analytics as a Service for Data Sharing Partners${NC}"
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

# ============================================================================
# Task 1: Create authorized views
# ============================================================================
echo -e "\n${YELLOW}[Task 1] Creating authorized views...${NC}"
bq --project_id="$PARTNER_PROJECT" mk --location=US "$DEMO_DATASET" >/dev/null 2>&1 || true
bq --project_id="$PARTNER_PROJECT" mk --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="TX" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_A" >/dev/null 2>&1 || echo "  $V_A may already exist."
bq --project_id="$PARTNER_PROJECT" mk --use_legacy_sql=false \
  --view 'SELECT * FROM `bigquery-public-data.geo_us_boundaries.zip_codes` WHERE state_code="CA" LIMIT 4000' \
  "$PARTNER_PROJECT:$DEMO_DATASET.$V_B" >/dev/null 2>&1 || echo "  $V_B may already exist."
echo -e "  Views:"; bq --project_id="$PARTNER_PROJECT" ls "$PARTNER_PROJECT:$DEMO_DATASET" 2>/dev/null | sed 's/^/    /' || true
echo -e "${GREEN}  ==> Task 1 DONE - check progress.${NC}"

# ============================================================================
# Task 2: Authorize views on dataset
# ============================================================================
echo -e "\n${YELLOW}[Task 2] Authorizing views on demo_dataset...${NC}"
for v in "$V_A" "$V_B"; do
  bq update --add_authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$v" "$PARTNER_PROJECT:$DEMO_DATASET" >/dev/null 2>&1 \
    || bq update --authorized_view "$PARTNER_PROJECT:$DEMO_DATASET.$v" "$PARTNER_PROJECT:$DEMO_DATASET" >/dev/null 2>&1 \
    || echo "  Authorize for $v failed (already set or needs console: demo_dataset -> Share -> Authorize views)."
done
echo -e "${GREEN}  ==> Task 2 DONE - check progress.${NC}"

# ============================================================================
# Task 3: Grant Data Viewer on the views to the customers
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
# Task 4 & 5: Customer-side - join + save result table
# ============================================================================
echo -e "\n${YELLOW}[Task 4/5] Customer-side BigQuery work...${NC}"

bq_query() { bq --project_id="$1" query --use_legacy_sql=false "$2" >/dev/null 2>&1; }

customer_side() {
  local cust_project="$1" user="$2" view="$3" cust_dataset="$4" table_name="$5"
  local partner="$PARTNER_PROJECT" demo="$DEMO_DATASET"
  echo -e "\n${CYAN}--- $cust_project : join + save ---${NC}"

  bq --project_id="$cust_project" mk --location=US "$cust_dataset" >/dev/null 2>&1 || true

  if bq_query "$cust_project" \
      "SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
       FROM \`$cust_project.$cust_dataset.customer_info\` as cust
       JOIN \`$partner.$demo.$view\` as geos
       ON geos.zip_code = cust.postal_code
       LIMIT 5"; then
    echo -e "${GREEN}    [OK] Join query ran.${NC}"
  else
    echo -e "${YELLOW}    [..] Join failed - check customer_info table exists.${NC}"
  fi

  if bq_query "$cust_project" \
      "CREATE OR REPLACE TABLE \`$cust_project.$cust_dataset.$table_name\` AS
       SELECT geos.zip_code, geos.city, cust.last_name, cust.first_name
       FROM \`$cust_project.$cust_dataset.customer_info\` as cust
       JOIN \`$partner.$demo.$view\` as geos
       ON geos.zip_code = cust.postal_code"; then
    echo -e "${GREEN}    [OK] Saved result to $cust_dataset.$table_name.${NC}"
  else
    echo -e "${YELLOW}    [..] Could not create $table_name - run query + Save view in console.${NC}"
  fi
}

if [ -n "$CUST_A_PROJECT" ]; then customer_side "$CUST_A_PROJECT" "$USER_A" "$V_A" "$CUST_A_DATASET" "customer_a_table"; fi
if [ -n "$CUST_B_PROJECT" ]; then customer_side "$CUST_B_PROJECT" "$USER_B" "$V_B" "$CUST_B_DATASET" "customer_b_table"; fi

# ============================================================================
# Manual browser steps for the Data Studio dashboards
# ============================================================================
print_dashboard_steps() {
  local cust_label="$1" cust_project="$2" cust_dataset="$3" table_name="$4" dash_name="$5" other_label="$6"
  echo -e "\n${BOLD}>>> MANUAL (browser) - $cust_label dashboard${NC}"
  echo -e "${CYAN}  1) Open https://lookerstudio.google.com (Data Studio), sign in as $cust_label user.${NC}"
  echo -e "${CYAN}  2) Create a Blank Report. If prompted, complete Account setup, then click Blank Report again.${NC}"
  echo -e "${CYAN}  3) In 'Add data to report' search 'BigQuery', click the BigQuery Connector.${NC}"
  echo -e "${CYAN}     Authorize + Allow access to BigQuery.${NC}"
  echo -e "${CYAN}  4) Select project: $cust_project > $cust_dataset > $table_name > Add > Add to Report.${NC}"
  echo -e "${CYAN}  5) Report name: $dash_name${NC}"
  echo -e "${CYAN}  6) Insert > Pie chart. On the chart Data tab: dimension = zip_code (replace with city),${NC}"
  echo -e "${CYAN}     metric = Record Count. Build the pie chart.${NC}"
  echo -e "${CYAN}  7) Share > Get report link > Copy Link. Sign out.${NC}"
  echo -e "${CYAN}  8) Security check: log in with the ${BOLD}$other_label user${NC}, open the link -> must be DENIED.${NC}"
  echo -e "${CYAN}     Click 'Check my progress' only after confirming access is denied.${NC}"
}

print_dashboard_steps "Customer A" "$CUST_A_PROJECT" "$CUST_A_DATASET" "customer_a_table" "Customer A Visualization" "Customer B"
print_dashboard_steps "Customer B" "$CUST_B_PROJECT" "$CUST_B_DATASET" "customer_b_table" "Customer B Visualization" "Customer A"

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}  GSP1042 SOLVER FINISHED - all scriptable steps done.${NC}"
echo -e "${GREEN}  Finish the two Data Studio dashboards with the MANUAL steps above,${NC}"
echo -e "${GREEN}  then click 'Check my progress'.${NC}"
echo -e "${GREEN}======================================================================${NC}"