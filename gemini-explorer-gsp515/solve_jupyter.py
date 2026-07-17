import os
import subprocess
import time
from google import genai
from google.genai import types

def get_project_id():
    try:
        return subprocess.check_output(['gcloud', 'config', 'get-value', 'project']).decode('utf-8').strip()
    except:
        return input("Enter Project ID: ")

PROJECT_ID = get_project_id()
LOCATION = "us-east1"

print(f"Using Project ID: {PROJECT_ID}")

client = genai.Client(vertexai={"project": PROJECT_ID, "location": LOCATION})

models_to_try = ["gemini-1.5-pro", "gemini-1.5-flash", "gemini-2.5-flash", "gemini-2.5-pro"]

# Task 2: Create a Function Call
print("\n--- Task 2: Create a Function Call ---")
get_current_weather_func = types.FunctionDeclaration(
    name="get_current_weather",
    description="Get the current weather in a given location",
    parameters={
        "type": "OBJECT",
        "properties": {
            "location": {
                "type": "STRING",
                "description": "The city and state, e.g. San Francisco, CA"
            }
        },
        "required": ["location"]
    }
)

weather_tool = types.Tool(
    function_declarations=[get_current_weather_func],
)

prompt = "What is the weather like in Boston?"

for model_id in models_to_try:
    print(f"Trying model {model_id} for function call...")
    try:
        response = client.models.generate_content(
            model=model_id,
            contents=prompt,
            config=types.GenerateContentConfig(
                tools=[weather_tool],
                temperature=0,
            ),
        )
        print("Success! Function Call Response generated.")
        print(response)
        break
    except Exception as e:
        print(f"Failed with {model_id}: {e}")

time.sleep(3)

# Task 3: Describe Video Contents
print("\n--- Task 3: Describe Video Contents ---")
for model_id in models_to_try:
    print(f"Trying model {model_id} for video description...")
    try:
        video_part = types.Part.from_uri(
            file_uri="gs://github-repo/img/gemini/multimodality_usecases_overview/mediterraneansea.mp4",
            mime_type="video/mp4",
        )
        prompt_video = "Describe the video from the given video URL attached."
        
        response_video = client.models.generate_content(
            model=model_id,
            contents=[video_part, prompt_video],
        )
        print("Success! Video Description generated.")
        print(response_video)
        break
    except Exception as e:
        print(f"Failed with {model_id}: {e}")

print("\nDone! Please check your progress in the lab.")
