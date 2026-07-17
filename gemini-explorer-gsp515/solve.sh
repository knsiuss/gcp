#!/bin/bash
# GSP515: Explore Generative AI with the Gemini API in Agent Platform: Challenge Lab
set -e

# Color codes for clean output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Starting automated solution for GSP515...${NC}"

# 1. Setup Environment
PROJECT_ID=$(gcloud config get-value project)

# Detect location dynamically
LOCATION=$(gcloud config get-value compute/region 2>/dev/null || echo "")
if [ -z "$LOCATION" ]; then
  # Try to detect via metadata server
  LOCATION=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4 | sed 's/-[a-z]$//' || echo "")
fi
if [ -z "$LOCATION" ]; then
  LOCATION="us-east1" # Fallback
fi

API_ENDPOINT="${LOCATION}-aiplatform.googleapis.com"
MODEL_ID="gemini-3.5-flash"

echo -e "${YELLOW}[*] Project ID:${NC} ${PROJECT_ID}"
echo -e "${YELLOW}[*] Region/Location:${NC} ${LOCATION}"
echo -e "${YELLOW}[*] Model ID:${NC} ${MODEL_ID}"

# Enable vertex / aiplatform APIs
echo -e "${YELLOW}Enabling aiplatform.googleapis.com...${NC}"
gcloud services enable aiplatform.googleapis.com --quiet || true

echo -e "${YELLOW}Task 1: Generating text using Gemini model via curl...${NC}"
curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json; charset=utf-8" \
  "https://${API_ENDPOINT}/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${MODEL_ID}:streamGenerateContent" \
  -d "{
    \"contents\": [{
      \"role\": \"user\",
      \"parts\": [{ \"text\": \"Why is the sky blue?\" }]
    }]
  }"

echo -e "\n${GREEN}Task 1 completed successfully!${NC}"

# 2. Find JupyterLab VM
echo -e "${YELLOW}Locating JupyterLab VM instance...${NC}"
VM_NAME="generative-ai-jupyterlab"
VM_ZONE=$(gcloud compute instances list --filter="name=${VM_NAME}" --format="value(zone)" --limit=1)

if [ -z "$VM_ZONE" ]; then
  echo -e "${YELLOW}JupyterLab VM not found with name ${VM_NAME}, checking all instances...${NC}"
  VM_ZONE=$(gcloud compute instances list --format="value(zone)" --limit=1)
  VM_NAME=$(gcloud compute instances list --format="value(name)" --limit=1)
fi

if [ -z "$VM_NAME" ] || [ -z "$VM_ZONE" ]; then
  echo -e "${RED}Error: Could not locate any JupyterLab VM instance in this project.${NC}"
  exit 1
fi

echo -e "${GREEN}Found instance: ${VM_NAME} in zone: ${VM_ZONE}${NC}"

# 3. Create update_notebook.py local script
echo -e "${YELLOW}Creating notebook updater helper script...${NC}"
cat << 'EOF' > /tmp/update_notebook.py
import json
import os
import glob
import re

# Find the notebook path under /home/jupyter/
notebook_files = glob.glob('/home/jupyter/**/*.ipynb', recursive=True)
notebook_path = None
for f in notebook_files:
    if 'gemini-explorer-challenge.ipynb' in f:
        notebook_path = f
        break

if not notebook_path:
    notebook_path = '/home/jupyter/gemini-explorer-challenge.ipynb'

print(f"Loading notebook from: {notebook_path}")

if not os.path.exists(notebook_path):
    print(f"Error: {notebook_path} does not exist.")
    exit(1)

with open(notebook_path, 'r') as f:
    data = json.load(f)

for cell in data['cells']:
    if cell['cell_type'] == 'code':
        source = "".join(cell['source'])
        
        # Check for Task 2.1 (Function calling model)
        if '# Task 2.1' in source or '#Task 2.1' in source:
            cell['source'] = [
                "# Task 2.1\n",
                "model = GenerativeModel(\"gemini-3.5-flash\")\n"
            ]
            print("Updated Task 2.1 cell.")
            
        # Check for Task 2.2 (Function declaration)
        elif '# Task 2.2' in source or '#Task 2.2' in source:
            cell['source'] = [
                "# Task 2.2\n",
                "get_current_weather_func = FunctionDeclaration(\n",
                "    name=\"get_current_weather\",\n",
                "    description=\"Get the current weather in a given location\",\n",
                "    parameters={\n",
                "        \"type\": \"object\",\n",
                "        \"properties\": {\n",
                "            \"location\": {\n",
                "                \"type\": \"string\",\n",
                "                \"description\": \"Location\"\n",
                "            }\n",
                "        }\n",
                "    },\n",
                ")\n"
            ]
            print("Updated Task 2.2 cell.")
            
        # Check for Task 2.3 (Tool definition)
        elif '# Task 2.3' in source or '#Task 2.3' in source:
            cell['source'] = [
                "# Task 2.3\n",
                "weather_tool = Tool(\n",
                "    function_declarations=[get_current_weather_func],\n",
                ")\n"
            ]
            print("Updated Task 2.3 cell.")
            
        # Check for Task 2.4 (Model call with tools)
        elif '# Task 2.4' in source or '#Task 2.4' in source:
            cell['source'] = [
                "# Task 2.4\n",
                "prompt = \"What is the weather like in Boston?\"\n",
                "response = model.generate_content(\n",
                "    prompt,\n",
                "    generation_config={\"temperature\": 0},\n",
                "    tools=[weather_tool],\n",
                ")\n",
                "response\n"
            ]
            print("Updated Task 2.4 cell.")
            
        # Check for Task 3.1 (Multimodal model loading)
        elif '# Task 3.1' in source or '#Task 3.1' in source:
            cell['source'] = [
                "# Task 3.1\n",
                "multimodal_model = GenerativeModel(model_name=\"gemini-3.5-flash\")\n"
            ]
            print("Updated Task 3.1 cell.")
            
        # Check for Task 3.2 (Video description)
        elif '# Task 3.2' in source or '#Task 3.2' in source or 'video description' in source.lower():
            # Find video URI from the source comments
            video_uri = "gs://github-repo/img/gemini/multimodality_usecases_overview/mediterraneansea.mp4"
            uri_match = re.search(r'(gs://\S+\.mp4)', source)
            if uri_match:
                video_uri = uri_match.group(1)
                print(f"Extracted video URI: {video_uri}")
                
            cell['source'] = [
                "# Task 3.2 Generate a video description\n",
                "prompt = \"Describe the video from the given video URL attached.\"\n",
                "video = Part.from_uri(\n",
                f"    uri=\"{video_uri}\",\n",
                "    mime_type=\"video/mp4\",\n",
                ")\n",
                "contents = [prompt, video]\n",
                "responses = multimodal_model.generate_content(contents, stream=True)\n",
                "print(\"-------Prompt--------\")\n",
                "print_multimodal_prompt(contents)\n"
            ]
            print("Updated Task 3.2 cell.")
            
        # Disable kernel shutdown cell if present
        elif 'do_shutdown(True)' in source:
            cell['source'] = [
                "# restart the kernel after libraries are loaded\n",
                "import IPython\n",
                "app = IPython.Application.instance()\n",
                "# app.kernel.do_shutdown(True)\n"
            ]
            print("Disabled kernel shutdown cell.")

with open(notebook_path, 'w') as f:
    json.dump(data, f, indent=1)

print("Notebook updated and saved successfully!")
EOF

# 4. Copy updater script to VM
echo -e "${YELLOW}Copying updater script to JupyterLab VM...${NC}"
gcloud compute scp --quiet /tmp/update_notebook.py ${VM_NAME}:/tmp/update_notebook.py --zone=${VM_ZONE}

# 5. Run updater script on VM
echo -e "${YELLOW}Running updater script on VM to modify the notebook...${NC}"
gcloud compute ssh --quiet ${VM_NAME} --zone=${VM_ZONE} --command="python3 /tmp/update_notebook.py"

# 6. Execute the notebook on the VM using jupyter nbconvert
echo -e "${YELLOW}Executing the notebook on the VM (this runs all cells and generates the required output)...${NC}"
gcloud compute ssh --quiet ${VM_NAME} --zone=${VM_ZONE} --command="find /home/jupyter/ -name 'gemini-explorer-challenge.ipynb' -exec jupyter nbconvert --to notebook --execute --inplace {} \;"

echo -e "${GREEN}All tasks completed successfully! Please wait a moment and check your progress on Qwiklabs.${NC}"
