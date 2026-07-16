import subprocess
import json
import time
import sys
import urllib.request
import urllib.parse

# 1. Fetch environment details dynamically
print("=== Fetching environment details dynamically ===")
PROJECT_ID = subprocess.check_output("gcloud config get-value project", shell=True).decode().strip()
ACTIVE_USER = subprocess.check_output("gcloud config get-value account", shell=True).decode().strip()
ZONE = subprocess.check_output("gcloud compute project-info describe --format='value(commonInstanceMetadata.items[google-compute-default-zone])'", shell=True).decode().strip()
REGION = "-".join(ZONE.split("-")[:2])

print(f"Project ID: {PROJECT_ID}")
print(f"Region: {REGION}")
print(f"Active User: {ACTIVE_USER}")

def run_cmd(cmd):
    print(f"\nRunning: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Message/Error: {res.stderr.strip()}")
    else:
        print(f"Success: {res.stdout.strip()}")
    return res

# 2. Enable Dataplex API
print("\n=== Enabling Dataplex API ===")
run_cmd("gcloud services enable dataplex.googleapis.com")
time.sleep(5)

# 3. Task 1: Create Lake & Zone
print("\n=== Task 1: Creating Lake ===")
run_cmd(f"gcloud dataplex lakes create customer-lake --location={REGION} --display-name='Customer-Lake'")
time.sleep(10)

print("\n=== Task 1: Creating Raw Zone ===")
run_cmd(f"gcloud dataplex zones create public-zone --lake=customer-lake --location={REGION} --display-name='Public-Zone' --type=RAW --resource-location-type=SINGLE_REGION --discovery-enabled --labels='domain_type=source_data'")

# Wait for Zone to become ACTIVE
print("\nWaiting for zone to become ACTIVE...")
for _ in range(30):
    res = subprocess.run(f"gcloud dataplex zones describe public-zone --lake=customer-lake --location={REGION} --format='value(state)'", shell=True, capture_output=True, text=True)
    state = res.stdout.strip()
    if state == "ACTIVE":
        print("Zone is ACTIVE!")
        break
    print(f"Zone state: {state or 'PENDING'}. Waiting 5s...")
    time.sleep(5)

# 4. Task 2: Attach GCS bucket asset
print("\n=== Task 2: Attaching Cloud Storage Bucket Asset ===")
run_cmd(f"gcloud dataplex assets create customer-raw-data --lake=customer-lake --zone=public-zone --location={REGION} --display-name='Customer Raw Data' --resource-type=STORAGE_BUCKET --resource-name=projects/{PROJECT_ID}/buckets/{PROJECT_ID}-customer-bucket --discovery-enabled --csv-header-rows=1 --csv-delimiter=',' --csv-encoding='UTF-8'")

# 5. Task 3: Attach BigQuery dataset asset
print("\n=== Task 3: Attaching BigQuery Dataset Asset ===")
run_cmd(f"gcloud dataplex assets create customer-details-dataset --lake=customer-lake --zone=public-zone --location={REGION} --display-name='Customer Details Dataset' --resource-type=BIGQUERY_DATASET --resource-name=projects/{PROJECT_ID}/datasets/customer_reference_data")

# Wait for asset to become ACTIVE
print("\nWaiting for customer-raw-data asset to become ACTIVE...")
for _ in range(30):
    res = subprocess.run(f"gcloud dataplex assets describe customer-raw-data --lake=customer-lake --zone=public-zone --location={REGION} --format='value(state)'", shell=True, capture_output=True, text=True)
    state = res.stdout.strip()
    if state == "ACTIVE":
        print("Asset is ACTIVE!")
        break
    print(f"Asset state: {state or 'PENDING'}. Waiting 5s...")
    time.sleep(5)

# 6. Task 4: Create Entity manually via REST API
print("\n=== Task 4: Creating Entity manually via REST API ===")
token = subprocess.check_output("gcloud auth print-access-token", shell=True).decode().strip()

entity_url = f"https://dataplex.googleapis.com/v1/projects/{PROJECT_ID}/locations/{REGION}/lakes/customer-lake/zones/public-zone/entities"

payload = {
    "id": "public_table",
    "displayName": "My Entity",
    "type": "TABLE",
    "asset": "customer-raw-data",
    "dataPath": f"gs://{PROJECT_ID}-customer-bucket",
    "system": "CLOUD_STORAGE",
    "format": {
        "format": "CSV"
    },
    "schema": {
        "userManaged": True
    }
}

req = urllib.request.Request(
    entity_url,
    data=json.dumps(payload).encode('utf-8'),
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as response:
        print("Entity 'My Entity' created successfully!")
        print(response.read().decode())
except Exception as e:
    print(f"Error creating entity: {e}")

print("\n=== ALL TASKS COMPLETED SUCCESSFULLY! ===")
