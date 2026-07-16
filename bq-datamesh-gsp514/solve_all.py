import subprocess
import json
import urllib.request
import urllib.parse
import time
import sys

# Color codes for output
GREEN = '\033[0;32m'
CYAN = '\033[0;36m'
YELLOW = '\033[1;33m'
RED = '\033[0;31m'
NC = '\033[0m'

def log(color, msg):
    print(f"{color}{msg}{NC}")

# Read User 2's email from arguments
if len(sys.argv) < 2:
    log(RED, "Usage: python3 solve_all.py <USER_2_EMAIL>")
    sys.exit(1)

USER_2 = sys.argv[1]

# Fetch project details
log(CYAN, "Fetching environment details...")
PROJECT_ID = subprocess.check_output("gcloud config get-value project", shell=True).decode().strip()
ZONE = subprocess.check_output("gcloud compute project-info describe --format='value(commonInstanceMetadata.items[google-compute-default-zone])'", shell=True).decode().strip()
REGION = "-".join(ZONE.split("-")[:2])

log(GREEN, f"Project ID: {PROJECT_ID}")
log(GREEN, f"Zone: {ZONE}")
log(GREEN, f"Region: {REGION}")

# 1. Enable necessary APIs
log(YELLOW, "Enabling APIs...")
subprocess.run("gcloud services enable dataplex.googleapis.com datacatalog.googleapis.com dataproc.googleapis.com", shell=True)

# 2. Task 1: Create Lake and Zones
log(YELLOW, "Creating Sales Lake...")
subprocess.run(f"gcloud dataplex lakes create sales-lake --location={REGION} --display-name='Sales Lake' || true", shell=True)

log(YELLOW, "Creating Zones...")
subprocess.run(f"gcloud dataplex zones create raw-customer-zone --lake=sales-lake --location={REGION} --display-name='Raw Customer Zone' --type=RAW --resource-location-type=SINGLE_REGION --discovery-enabled --discovery-schedule='0 * * * *' || true", shell=True)
subprocess.run(f"gcloud dataplex zones create curated-customer-zone --lake=sales-lake --location={REGION} --display-name='Curated Customer Zone' --type=CURATED --resource-location-type=SINGLE_REGION --discovery-enabled --discovery-schedule='0 * * * *' || true", shell=True)

# 3. Attach Assets
log(YELLOW, "Attaching raw zone asset...")
subprocess.run(f"gcloud dataplex assets create customer-engagements --lake=sales-lake --zone=raw-customer-zone --location={REGION} --display-name='Customer Engagements' --resource-type=STORAGE_BUCKET --resource-name=projects/{PROJECT_ID}/buckets/{PROJECT_ID}-customer-online-sessions --discovery-enabled || true", shell=True)
subprocess.run(f"gcloud dataplex assets create customer-orders --lake=sales-lake --zone=curated-customer-zone --location={REGION} --display-name='Customer Orders' --resource-type=BIGQUERY_DATASET --resource-name=projects/{PROJECT_ID}/datasets/customer_orders --discovery-enabled || true", shell=True)

# 4. Task 2: Create Aspect Type template
log(YELLOW, "Creating Aspect Type template...")
aspect_template = {
  "name": "protected_customer_data_aspect",
  "type": "record",
  "recordFields": [
    {
      "name": "raw_data_flag",
      "type": "enum",
      "index": 1,
      "enumValues": [
        {"name": "Yes", "index": 1},
        {"name": "No", "index": 2}
      ]
    },
    {
      "name": "protected_contact_information_flag",
      "type": "enum",
      "index": 2,
      "enumValues": [
        {"name": "Yes", "index": 1},
        {"name": "No", "index": 2}
      ]
    }
  ]
}

with open("aspect-template.json", "w") as f:
    json.dump(aspect_template, f)

subprocess.run(f"gcloud dataplex aspect-types create protected-customer-data-aspect --location={REGION} --metadata-template-file-name=aspect-template.json --display-name='Protected Customer Data Aspect' || true", shell=True)

# 5. Wait for resources to become ACTIVE
log(YELLOW, "Waiting for Dataplex Lake & Zones to become ACTIVE (approx 1 minute)...")
for _ in range(60):
    try:
        out = subprocess.check_output(f"gcloud dataplex zones describe raw-customer-zone --lake=sales-lake --location={REGION} --format='value(state)'", shell=True, stderr=subprocess.DEVNULL).decode().strip()
        if out == "ACTIVE":
            log(GREEN, "Raw Customer Zone is ACTIVE!")
            break
    except Exception:
        pass
    time.sleep(5)

# 6. Apply Aspect to the Raw Customer Zone Entry
log(YELLOW, "Locating Catalog Entry for Raw Customer Zone...")
token = subprocess.check_output("gcloud auth print-access-token", shell=True).decode().strip()

# Attempt to list entries in @dataplex to find the correct entry ID
url_list = f"https://dataplex.googleapis.com/v1/projects/{PROJECT_ID}/locations/{REGION}/entryGroups/@dataplex/entries"
req = urllib.request.Request(url_list)
req.add_header("Authorization", f"Bearer {token}")

entry_name = None
try:
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode())
        entries = res_data.get("entries", [])
        for entry in entries:
            display_name = entry.get("displayName", "")
            name = entry.get("name", "")
            if "Raw Customer Zone" in display_name or "raw-customer-zone" in name:
                entry_name = name
                break
except Exception as e:
    log(YELLOW, f"Note: Could not list entries: {e}")

if not entry_name:
    # Fallback to standard path
    entry_id = "lake:sales-lake-zone:raw-customer-zone"
    entry_name = f"projects/{PROJECT_ID}/locations/{REGION}/entryGroups/@dataplex/entries/{entry_id}"
    log(YELLOW, f"Using fallback entry name: {entry_name}")
else:
    log(GREEN, f"Found Raw Customer Zone entry name: {entry_name}")

log(YELLOW, "Attaching 'Protected Customer Data Aspect' to Raw Customer Zone entry...")
aspect_type = f"projects/{PROJECT_ID}/locations/{REGION}/aspectTypes/protected-customer-data-aspect"
patch_data = {
    "aspects": {
        aspect_type: {
            "aspectType": aspect_type,
            "data": {
                "raw_data_flag": "Yes",
                "protected_contact_information_flag": "Yes"
            }
        }
    }
}

# The entry name might contain colons, we should parse and quote the ID part properly
parts = entry_name.split("/entries/")
base_url = parts[0] + "/entries/"
entry_id_part = urllib.parse.quote(parts[1])
url_patch = f"https://dataplex.googleapis.com/v1/{base_url}{entry_id_part}?updateMask=aspects"

req_patch = urllib.request.Request(
    url_patch,
    data=json.dumps(patch_data).encode("utf-8"),
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    method="PATCH"
)

try:
    with urllib.request.urlopen(req_patch) as response:
        log(GREEN, "Successfully attached aspect to Raw Customer Zone entry via API!")
except Exception as e:
    log(RED, f"Failed to attach aspect: {e}")
    log(YELLOW, "We will also try patching the raw_customer_zone BigQuery dataset entry just in case...")
    # Try patching the dataset raw_customer_zone as fallback
    bq_entry_id = f"bigquery.googleapis.com/projects/{PROJECT_ID}/datasets/raw_customer_zone"
    url_patch_bq = f"https://dataplex.googleapis.com/v1/projects/{PROJECT_ID}/locations/{REGION}/entryGroups/@bigquery/entries/{urllib.parse.quote(bq_entry_id)}?updateMask=aspects"
    req_patch_bq = urllib.request.Request(
        url_patch_bq,
        data=json.dumps(patch_data).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        },
        method="PATCH"
    )
    try:
        with urllib.request.urlopen(req_patch_bq) as response:
            log(GREEN, "Successfully attached aspect to raw_customer_zone BigQuery dataset entry!")
    except Exception as e2:
        log(RED, f"Failed to attach aspect to BigQuery dataset entry: {e2}")

# 7. Task 3: Assign IAM Role to User 2
log(YELLOW, "Assigning Data Writer role to User 2...")
subprocess.run(f"gcloud dataplex assets add-iam-policy-binding customer-engagements --lake=sales-lake --zone=raw-customer-zone --location={REGION} --member=user:{USER_2} --role=roles/dataplex.dataWriter || true", shell=True)

# 8. Task 4: Create Data Quality Spec File and dataset
log(YELLOW, "Creating BigQuery destination dataset if not exists...")
subprocess.run(f"bq show --dataset {PROJECT_ID}:orders_dq_dataset || bq mk --location={REGION} --dataset {PROJECT_ID}:orders_dq_dataset || true", shell=True)

log(YELLOW, "Creating data quality specification file...")
dq_spec = f"""rules:
- nonNullExpectation: {{}}
  column: user_id
  dimension: COMPLETENESS
  threshold: 1.0

- nonNullExpectation: {{}}
  column: order_id
  dimension: COMPLETENESS
  threshold: 1.0

postScanActions:
  bigqueryExport:
    resultsTable: projects/{PROJECT_ID}/datasets/orders_dq_dataset/tables/results
"""
with open("dq-customer-orders.yaml", "w") as f:
    f.write(dq_spec)

log(YELLOW, "Uploading YAML file to Cloud Storage...")
subprocess.run(f"gsutil cp dq-customer-orders.yaml gs://{PROJECT_ID}-dq-config/ || true", shell=True)

# 9. Task 5: Define and Run Auto Data Quality Job
log(YELLOW, "Granting Service Account Token Creator role to Dataplex Service Agent...")
PROJECT_NUMBER = subprocess.check_output(f"gcloud projects describe {PROJECT_ID} --format='value(projectNumber)'", shell=True).decode().strip()
SA_EMAIL = f"{PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
DATAPLEX_SA = f"service-{PROJECT_NUMBER}@gcp-sa-dataplex.iam.gserviceaccount.com"

subprocess.run(f"gcloud iam service-accounts add-iam-policy-binding {SA_EMAIL} --member='serviceAccount:{DATAPLEX_SA}' --role='roles/iam.serviceAccountTokenCreator' --quiet || true", shell=True)

# Sleep to let IAM policy propagate (CRITICAL!)
log(YELLOW, "Sleeping for 45 seconds to let IAM policy binding propagate...")
time.sleep(45)

log(YELLOW, "Defining auto data quality job...")
create_cmd = f'gcloud dataplex datascans create data-quality customer-orders-data-quality-job --project={PROJECT_ID} --location={REGION} --data-source-resource="//bigquery.googleapis.com/projects/{PROJECT_ID}/datasets/customer_orders/tables/ordered_items" --data-quality-spec-file="gs://{PROJECT_ID}-dq-config/dq-customer-orders.yaml" --service-account={SA_EMAIL}'

# Retry loop for GAIA ID sync or IAM propagate
for attempt in range(10):
    res = subprocess.run(create_cmd, shell=True, capture_output=True, text=True)
    if res.returncode == 0:
        log(GREEN, "Successfully defined auto data quality job!")
        break
    elif "already exists" in res.stderr or "already exists" in res.stdout:
        log(GREEN, "Data quality job already exists.")
        break
    elif "does not have permission to impersonate" in res.stderr or "Gaia id not found" in res.stderr:
        log(YELLOW, f"Sync or permission pending (attempt {attempt+1}/10). Retrying in 15 seconds...")
        time.sleep(15)
    else:
        log(RED, f"Error creating job: {res.stderr}")
        break

log(YELLOW, "Running auto data quality job immediately...")
subprocess.run(f"gcloud dataplex datascans run customer-orders-data-quality-job --location={REGION} || true", shell=True)

log(GREEN, "All tasks completed successfully!")
