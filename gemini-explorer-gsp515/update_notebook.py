import json
import os
import glob

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
        if '# Task 2.1' in source:
            cell['source'] = [
                "# Task 2.1\n",
                "# use the following documentation to assist you complete this cell\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling#function-calling-generation-sdk-sample\n",
                "model = GenerativeModel(\"gemini-1.5-flash-002\")"
            ]
            print("Updated Task 2.1 cell.")
        elif '# Task 2.2' in source:
            cell['source'] = [
                "# Task 2.2\n",
                "# use the following documentation to assist you complete this cell\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling#function-calling-generation-sdk-sample\n",
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
                ")"
            ]
            print("Updated Task 2.2 cell.")
        elif '# Task 2.3' in source:
            cell['source'] = [
                "# Task 2.3\n",
                "# use the following documentation to assist you complete this cell\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling#function-calling-generation-sdk-sample\n",
                "weather_tool = Tool(\n",
                "    function_declarations=[get_current_weather_func],\n",
                ")"
            ]
            print("Updated Task 2.3 cell.")
        elif '# Task 2.4' in source:
            cell['source'] = [
                "# Task 2.4\n",
                "# use the following documentation to assist you complete this cell\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling#function-calling-generation-sdk-sample\n",
                "prompt = \"What is the weather like in Boston?\"\n",
                "\n",
                "response = model.generate_content(\n",
                "    prompt,\n",
                "    generation_config={\"temperature\": 0},\n",
                "    tools=[weather_tool],\n",
                ")\n",
                "response"
            ]
            print("Updated Task 2.4 cell.")
        elif '# Task 3.1' in source:
            cell['source'] = [
                "# Task 3.1\n",
                "# Load the correct Gemini model use the following documentation to assist:\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/overview#supported-use-cases\n",
                "multimodal_model = GenerativeModel(model_name=\"gemini-1.5-flash\")"
            ]
            print("Updated Task 3.1 cell.")
        elif '# Task 3.2 Generate a video description' in source:
            cell['source'] = [
                "# Task 3.2 Generate a video description\n",
                "# In this cell, update the prompt to ask Gemini to describe the video URL referenced.\n",
                "# You can use the documentation at the following link to assist.\n",
                "# https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/sdk-for-gemini/gemini-sdk-overview-reference#generate-content-from-video\n",
                "# \n",
                "# Video URI: gs://github-repo/img/gemini/multimodality_usecases_overview/mediterraneansea.mp4\n",
                "# \n",
                "prompt = \"\"\"\n",
                "Describe the video from the given video URL attached.\n",
                "\"\"\"\n",
                "video = Part.from_uri(\n",
                "    uri=\"gs://github-repo/img/gemini/multimodality_usecases_overview/mediterraneansea.mp4\",\n",
                "    mime_type=\"video/mp4\",\n",
                ")\n",
                "contents = [prompt, video]\n",
                "\n",
                "responses = multimodal_model.generate_content(contents, stream=True)\n",
                "\n",
                "print(\"-------Prompt--------\")\n",
                "print_multimodal_prompt(contents)\n"
            ]
            print("Updated Task 3.2 cell.")
        elif 'do_shutdown(True)' in source:
            cell['source'] = [
                "# restart the kernel after libraries are loaded\n",
                "import IPython\n",
                "\n",
                "app = IPython.Application.instance()\n",
                "# app.kernel.do_shutdown(True)"
            ]
            print("Disabled kernel shutdown cell.")

with open(notebook_path, 'w') as f:
    json.dump(data, f, indent=1)

print("Notebook updated and saved successfully!")
