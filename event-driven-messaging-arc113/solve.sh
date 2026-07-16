#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Set Region
export REGION="us-east1"

# 1. Enable APIs
echo "Enabling necessary APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com

# 2. Task 1: Create Pub/Sub schema 'city-temp-schema'
echo "Creating Pub/Sub schema 'city-temp-schema'..."
gcloud pubsub schemas create city-temp-schema \
  --type=avro \
  --definition='{"type":"record","name":"Avro","fields":[{"name":"city","type":"string"},{"name":"temperature","type":"double"},{"name":"pressure","type":"int"},{"name":"time_position","type":"string"}]}'

# 3. Task 2: Create Pub/Sub topic 'temp-topic' using pre-created schema 'temperature-schema'
echo "Waiting for pre-created temperature-schema to be provisioned by Qwiklabs..."
until gcloud pubsub schemas describe temperature-schema >/dev/null 2>&1; do
  echo "Still waiting for temperature-schema..."
  sleep 5
done
echo "temperature-schema is ready! Creating temp-topic..."
gcloud pubsub topics create temp-topic \
  --schema=temperature-schema \
  --message-encoding=json

# 4. Task 3: Create a trigger cloud function 'gcf-pubsub' for topic 'gcf-topic'
echo "Creating topic 'gcf-topic'..."
gcloud pubsub topics create gcf-topic || true

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
