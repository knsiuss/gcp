#!/bin/bash
# ARC132: Implement Speech and Language Solutions with Pre-trained APIs: Challenge Lab
set -e

# Color codes for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}   ARC132 Automation Script by Antigravity      ${NC}"
echo -e "${CYAN}================================================${NC}"

# Read API Key
read -p "Enter your Task 1 API Key: " API_KEY
if [ -z "$API_KEY" ]; then
  echo -e "${RED}API Key is required!${NC}"
  exit 1
fi

# Read Task 2 output file name
read -p "Enter Task 2 output file name [synthesize-text.txt]: " TASK_2_FILE_NAME
TASK_2_FILE_NAME=${TASK_2_FILE_NAME:-"synthesize-text.txt"}

# Read Task 3 request file name
read -p "Enter Task 3 request file name [french-request.json]: " TASK_3_REQUEST_FILE
TASK_3_REQUEST_FILE=${TASK_3_REQUEST_FILE:-"french-request.json"}

# Read Task 3 response file name
read -p "Enter Task 3 response file name [french-response.json]: " TASK_3_RESPONSE_FILE
TASK_3_RESPONSE_FILE=${TASK_3_RESPONSE_FILE:-"french-response.json"}

# Read Task 4 sentence to translate
echo -e "${YELLOW}Example: La plume est plus forte que l'épée.${NC}"
read -p "Enter Task 4 sentence to translate: " TASK_4_SENTENCE
if [ -z "$TASK_4_SENTENCE" ]; then
  echo -e "${RED}Task 4 sentence is required!${NC}"
  exit 1
fi

# Read Task 4 output file name
read -p "Enter Task 4 output file name [translation.txt]: " TASK_4_FILE_NAME
TASK_4_FILE_NAME=${TASK_4_FILE_NAME:-"translation.txt"}

# Read Task 5 sentence to detect
echo -e "${YELLOW}Example: %E3%81%93%E3%82%93%E3%81%AB%E3%81%A1%E3%81%AF${NC}"
read -p "Enter Task 5 sentence to detect (often URL-encoded): " TASK_5_SENTENCE
if [ -z "$TASK_5_SENTENCE" ]; then
  echo -e "${RED}Task 5 sentence is required!${NC}"
  exit 1
fi

# Read Task 5 output file name
read -p "Enter Task 5 output file name [detection.txt]: " TASK_5_FILE_NAME
TASK_5_FILE_NAME=${TASK_5_FILE_NAME:-"detection.txt"}

# Get project details
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute instances list --filter="name=lab-vm" --format="value(zone)" --limit=1)

if [ -z "$ZONE" ]; then
  export ZONE="us-central1-a"
fi

echo -e "${GREEN}Project ID: $PROJECT_ID${NC}"
echo -e "${GREEN}Zone: $ZONE${NC}"

# Pre-generate SSH keys for non-interactive access
if [ ! -f ~/.ssh/google_compute_engine ]; then
  echo -e "${YELLOW}Pre-generating SSH keys for non-interactive access...${NC}"
  mkdir -p ~/.ssh
  ssh-keygen -t rsa -N "" -f ~/.ssh/google_compute_engine
fi

# Create a tasks runner script that will run inside lab-vm
cat << EOF_VM > run_tasks.sh
#!/bin/bash
set -e

# Activate the venv
source venv/bin/activate

# Task 2: Create synthesize-text.json
cat << 'EOF_JSON' > synthesize-text.json
{
    "input":{
        "text":"Cloud Text-to-Speech API allows developers to include natural-sounding, synthetic human speech as playable audio in their applications. The Text-to-Speech API converts text or Speech Synthesis Markup Language (SSML) input into audio data like MP3 or LINEAR16 (the encoding used in WAV files)."
    },
    "voice":{
        "languageCode":"en-gb",
        "name":"en-GB-Standard-A",
        "ssmlGender":"FEMALE"
    },
    "audioConfig":{
        "audioEncoding":"MP3"
    }
}
EOF_JSON

# Call TTS API and output to TASK_2_FILE_NAME
curl -H "X-Goog-Api-Key: ${API_KEY}" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d @synthesize-text.json "https://texttospeech.googleapis.com/v1/text:synthesize" \
  > "${TASK_2_FILE_NAME}"

# Create tts_decode.py
cat << 'EOF_PY' > tts_decode.py
import argparse
from base64 import decodebytes
import json

def decode_tts_output(input_file, output_file):
    with open(input_file) as input:
        response = json.load(input)
        audio_data = response['audioContent']
        with open(output_file, "wb") as new_file:
            new_file.write(decodebytes(audio_data.encode('utf-8')))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Decode output from Cloud Text-to-Speech")
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    decode_tts_output(args.input, args.output)
EOF_PY

# Run tts_decode.py
python3 tts_decode.py --input "${TASK_2_FILE_NAME}" --output "synthesize-text-audio.mp3"

# Task 3: Transcribe audio to French
cat << 'EOF_JSON3' > "${TASK_3_REQUEST_FILE}"
{
  "config": {
    "encoding": "FLAC",
    "sampleRateHertz": 44100,
    "languageCode": "fr-FR"
  },
  "audio": {
    "uri": "gs://cloud-samples-data/speech/corbeau_renard.flac"
  }
}
EOF_JSON3

curl -s -X POST -H "Content-Type: application/json" \
    --data-binary @"${TASK_3_REQUEST_FILE}" \
    "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
    -o "${TASK_3_RESPONSE_FILE}"

# Task 4: Translate French sentence to English (auto-detect source, output English)
response=\$(curl -s -X POST \
  -H "Authorization: Bearer \$(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"q\": \"${TASK_4_SENTENCE}\"}" \
  "https://translation.googleapis.com/language/translate/v2?key=${API_KEY}&target=en")

echo "\$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['translations'][0]['translatedText'])" > "${TASK_4_FILE_NAME}"

# Task 5: Detect language of URL-encoded sentence
decoded_sentence=\$(python3 -c "import urllib.parse; print(urllib.parse.unquote('${TASK_5_SENTENCE}'))")
curl -s -X POST \
  -H "Authorization: Bearer \$(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"q\": [\"\$decoded_sentence\"]}" \
  "https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}" \
  > "${TASK_5_FILE_NAME}"

echo "VM Tasks executed successfully."
EOF_VM

# SCP the runner script to lab-vm and execute it
gcloud compute scp run_tasks.sh lab-vm:/tmp --zone=${ZONE} --quiet
gcloud compute ssh lab-vm --zone=${ZONE} --quiet --command="bash /tmp/run_tasks.sh"

echo -e "${GREEN}ARC132 lab execution completed successfully!${NC}"
