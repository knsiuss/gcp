import subprocess
import time
import sys

print("=== Starting ARC114 Automation ===")

# 1. Enable APIs
print("Enabling necessary APIs...")
subprocess.run("gcloud services enable language.googleapis.com speech.googleapis.com", shell=True)

# 2. Find VM name and zone
print("Locating VM instance...")
res_instances = subprocess.run("gcloud compute instances list --format='value(name,zone)'", shell=True, capture_output=True, text=True)
instances = res_instances.stdout.strip().split('\n')
if not instances or not instances[0]:
    print("Error: No VM instances found.")
    sys.exit(1)

vm_name, zone = instances[0].split('\t')
print(f"VM Name: {vm_name}, Zone: {zone}")

# 3. Create or retrieve API Key
print("Retrieving or creating API Key...")
subprocess.run("gcloud beta services api-keys create --display-name='ARC114 API Key' 2>/dev/null || true", shell=True)
api_key = subprocess.check_output("gcloud beta services api-keys list --format='value(keyString)' --limit=1", shell=True).decode().strip()
if not api_key:
    print("Error: Could not retrieve API Key.")
    sys.exit(1)
print(f"API Key: {api_key[:10]}...")

# 4. Prepare setup script for VM
vm_setup_content = f"""#!/bin/bash
export API_KEY="{api_key}"

echo "=== Running Tasks on VM ==="

# Task 2: Entity analysis request
cat << 'EOF' > nl_request.json
{{
  "document":{{
    "type":"PLAIN_TEXT",
    "content":"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  }},
  "encodingType":"UTF8"
}}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @nl_request.json "https://language.googleapis.com/v1/documents:analyzeEntities?key=${{API_KEY}}" -o nl_response.json
echo "Task 2 completed. nl_response.json created."

# Task 3: Speech analysis request
cat << 'EOF' > speech_request.json
{{
  "config": {{
      "encoding":"FLAC",
      "languageCode": "en-US"
  }},
  "audio": {{
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }}
}}
EOF

curl -s -X POST -H "Content-Type: application/json" --data-binary @speech_request.json "https://speech.googleapis.com/v1/speech:recognize?key=${{API_KEY}}" -o speech_response.json
echo "Task 3 completed. speech_response.json created."

# Task 4: Sentiment Analysis Python code
# Search for sentiment_analysis.py in home directory
FILE_PATH=$(find ~ -name "sentiment_analysis.py" | head -n 1)
if [ -z "$FILE_PATH" ]; then
  FILE_PATH="./sentiment_analysis.py"
fi
echo "Editing file at: $FILE_PATH"

python3 - << 'EOF_PY'
import re

with open('$FILE_PATH', 'r') as f:
    code = f.read()

# Define the complete correct analyze function
correct_fn = \"\"\"def analyze(movie_review_filename):
    client = language_v1.LanguageServiceClient()
    with open(movie_review_filename, 'r') as review_file:
        content = review_file.read()
    document = language_v1.Document(
        content=content,
        type_=language_v1.Document.Type.PLAIN_TEXT
    )
    annotations = client.analyze_sentiment(request={'document': document})
    print(f"Overall Sentiment: score of {annotations.document_sentiment.score} with magnitude of {annotations.document_sentiment.magnitude}")
    return annotations\"\"\"

# Replace analyze function block in code using regex
pattern = r"def analyze\(movie_review_filename\):.*?return\s+\w+"
modified_code, count = re.subn(pattern, correct_fn, code, flags=re.DOTALL)
if count == 0:
    pattern_fallback = r"def analyze\(movie_review_filename\):.*?(?=(def|if __name__))"
    modified_code, count = re.subn(pattern_fallback, correct_fn + "\\n\\n", code, flags=re.DOTALL)

with open('$FILE_PATH', 'w') as f:
    f.write(modified_code)
print("sentiment_analysis.py modified successfully.")
EOF_PY

# Download samples
gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
tar -xvzf sentiment-samples.tgz

# Run sentiment analysis on bladerunner-pos.txt
python3 sentiment_analysis.py reviews/bladerunner-pos.txt

echo "=== All VM tasks completed successfully! ==="
"""

with open("vm_setup.sh", "w") as f:
    f.write(vm_setup_content)

# 5. SCP setup script to VM
print("Copying setup script to VM...")
subprocess.run(f"gcloud compute scp vm_setup.sh {vm_name}:/tmp --zone={zone} --quiet", shell=True)

# 6. SSH to VM and run setup script
print("Running setup script on VM...")
subprocess.run(f"gcloud compute ssh {vm_name} --zone={zone} --command='bash /tmp/vm_setup.sh' --quiet", shell=True)

print("=== ALL TASKS COMPLETED! ===")
