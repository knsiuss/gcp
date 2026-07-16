#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Set Region
export REGION="us-east1"
export PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects list --filter="projectId:$PROJECT_ID" --format="value(projectNumber)")

# 1. Enable APIs
echo "Enabling necessary APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com

# 2. Provision Pub/Sub service identity if it doesn't exist
echo "Provisioning Pub/Sub service identity..."
gcloud beta services identity create --service=pubsub.googleapis.com --project=$PROJECT_ID || true

# Grant Service Account Token Creator role
echo "Granting Service Account Token Creator role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator || true

# 3. Task 1: Create Pub/Sub schema 'city-temp-schema'
if ! gcloud pubsub schemas describe city-temp-schema >/dev/null 2>&1; then
  echo "Creating Pub/Sub schema 'city-temp-schema'..."
  gcloud pubsub schemas create city-temp-schema \
    --type=avro \
    --definition='{"type":"record","name":"Avro","fields":[{"name":"city","type":"string"},{"name":"temperature","type":"double"},{"name":"pressure","type":"int"},{"name":"time_position","type":"string"}]}'
else
  echo "city-temp-schema already exists."
fi

# 4. Task 2: Create Pub/Sub topic 'temp-topic' using pre-created schema 'temperature-schema'
echo "Waiting for pre-created temperature-schema to be provisioned by Qwiklabs..."
until gcloud pubsub schemas describe temperature-schema >/dev/null 2>&1; do
  echo "Still waiting for temperature-schema..."
  sleep 5
done
echo "temperature-schema is ready!"

if ! gcloud pubsub topics describe temp-topic >/dev/null 2>&1; then
  echo "Creating temp-topic..."
  gcloud pubsub topics create temp-topic \
    --schema=temperature-schema \
    --message-encoding=json
else
  echo "temp-topic already exists."
fi

# 5. Task 3: Create a trigger cloud function 'gcf-pubsub' for topic 'gcf-topic'
if ! gcloud pubsub topics describe gcf-topic >/dev/null 2>&1; then
  echo "Creating topic 'gcf-topic'..."
  gcloud pubsub topics create gcf-topic
else
  echo "gcf-topic already exists."
fi

# Prepare the Cloud Function code
echo "Preparing Cloud Function code..."
mkdir -p gcf-pubsub-code
cd gcf-pubsub-code

cat << 'EOF' > index.js
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('helloPubSub', cloudEvent => {
  const base64name = cloudEvent.data.message.data;
  const name = base64name ? Buffer.from(base64name, 'base64').toString() : 'World';
  console.log(`Hello, ${name}!`);
});
EOF

cat << 'EOF' > package.json
{
  "name": "gcf-pubsub",
  "version": "0.0.1",
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

# Deploy the function
echo "Deploying trigger cloud function 'gcf-pubsub'..."
gcloud functions deploy gcf-pubsub \
  --gen2 \
  --runtime=nodejs20 \
  --entry-point=helloPubSub \
  --trigger-topic=gcf-topic \
  --region=$REGION \
  --allow-unauthenticated

echo "SUCCESS: All tasks configured successfully!"
