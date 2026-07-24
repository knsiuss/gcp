#!/usr/bin/env python3
"""
GSP531 - Google DeepMind: Train a Small Language Model (Challenge Lab)
Automated Solution Script for Cloud Shell
"""

import json
import os
import sys
import subprocess

def run_cmd(cmd, check=True):
    print(f"Running: {cmd}")
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and res.returncode != 0:
        print(f"Error: {res.stderr}")
    return res.stdout, res.stderr, res.returncode

def main():
    print("======================================================================")
    print("  GSP531 - Train a Small Language Model Solver")
    print("======================================================================")

    # Get Project ID
    project_id, _, _ = run_cmd("gcloud config get-value project")
    project_id = project_id.strip()
    print(f"Project ID: {project_id}")

    bucket_name = f"{project_id}-bucket"
    notebook_name = "gdm_challenge_lab.ipynb"
    gcs_path = f"gs://{bucket_name}/{notebook_name}"

    print(f"Downloading notebook from {gcs_path}...")
    run_cmd(f"gsutil cp {gcs_path} ./gdm_challenge_lab.ipynb")

    if not os.path.exists("gdm_challenge_lab.ipynb"):
        print("Failed to download notebook! Trying fallback download...")
        run_cmd(f"gcloud storage cp {gcs_path} ./gdm_challenge_lab.ipynb")

    if not os.path.exists("gdm_challenge_lab.ipynb"):
        print("ERROR: Could not find gdm_challenge_lab.ipynb")
        sys.exit(1)

    print("Reading notebook JSON...")
    with open("gdm_challenge_lab.ipynb", "r", encoding="utf-8") as f:
        nb = json.load(f)

    # Print out notebook cell snippets for inspection
    print("\n--- Inspecting Notebook Cells ---")
    for idx, cell in enumerate(nb.get("cells", [])):
        cell_type = cell.get("cell_type")
        source = "".join(cell.get("source", []))
        if "TODO" in source or "def " in source or "class " in source:
            print(f"\n[Cell {idx} - {cell_type}]")
            print(source[:500])

    print("\n--- Applying Code Solutions to TODO Cells ---")

    modified = False
    for idx, cell in enumerate(nb.get("cells", [])):
        if cell.get("cell_type") != "code":
            continue
        source = "".join(cell.get("source", []))

        # Task 2: SimpleArabicCharacterTokenizer
        if "class SimpleArabicCharacterTokenizer" in source or "def character_tokenize" in source:
            print(f"Patching Task 2 (SimpleArabicCharacterTokenizer) in Cell {idx}...")

            # Replace character_tokenize TODO
            if "def character_tokenize" in source:
                # Replace pass or [TODO] in character_tokenize
                cell_source = "".join(cell["source"])

                # Standard character_tokenize implementation
                char_tok_replacement = """    def character_tokenize(self, text: str) -> list[str]:
        # TODO - Add your code here
        return list(text)"""

                join_text_replacement = """    def join_text(self, tokens: list[str]) -> str:
        # TODO - Add your code here
        return "".join(tokens)"""

                # Replace character_tokenize body
                lines = cell_source.split("\n")
                new_lines = []
                in_char_tok = False
                in_join_text = False

                for line in lines:
                    if "def character_tokenize" in line:
                        in_char_tok = True
                        in_join_text = False
                        new_lines.append(line)
                        continue
                    elif "def join_text" in line:
                        in_char_tok = False
                        in_join_text = True
                        new_lines.append(line)
                        continue
                    elif line.strip().startswith("def ") or line.strip().startswith("class "):
                        in_char_tok = False
                        in_join_text = False

                    if in_char_tok:
                        if "return list(text)" not in line and ("pass" in line or "TODO" in line or line.strip() == ""):
                            if not any("return list(text)" in l for l in new_lines):
                                new_lines.append("        return list(text)")
                            continue
                        else:
                            new_lines.append(line)
                    elif in_join_text:
                        if "return \"\".join(tokens)" not in line and ("pass" in line or "TODO" in line or line.strip() == ""):
                            if not any("return \"\".join(tokens)" in l for l in new_lines):
                                new_lines.append("        return \"\".join(tokens)")
                            continue
                        else:
                            new_lines.append(line)
                    else:
                        new_lines.append(line)

                cell["source"] = [l + "\n" for l in new_lines]
                modified = True

        # Task 3: generate_text_from_ngram_model
        if "def generate_text_from_ngram_model" in source:
            print(f"Patching Task 3 (generate_text_from_ngram_model) in Cell {idx}...")

            gen_text_code = [
                "def generate_text_from_ngram_model(model, prompt, max_length, sampling_mode='random'):\n",
                "    # TODO - Add your code here\n",
                "    generated_tokens = list(prompt)\n",
                "    n = getattr(model, 'n', 3)\n",
                "    while len(generated_tokens) < max_length:\n",
                "        context = tuple(generated_tokens[-(n-1):]) if n > 1 else ()\n",
                "        if hasattr(model, 'get_next_token_probs'):\n",
                "            probs_dict = model.get_next_token_probs(context)\n",
                "        elif hasattr(model, 'predict_next'):\n",
                "            probs_dict = model.predict_next(context)\n",
                "        elif isinstance(model, dict):\n",
                "            probs_dict = model.get(context, {})\n",
                "        else:\n",
                "            try:\n",
                "                probs_dict = model[context]\n",
                "            except:\n",
                "                probs_dict = {}\n",
                "        if not probs_dict:\n",
                "            break\n",
                "        tokens = list(probs_dict.keys())\n",
                "        probs = list(probs_dict.values())\n",
                "        import numpy as np\n",
                "        if sampling_mode == 'greedy':\n",
                "            next_token = tokens[np.argmax(probs)]\n",
                "        else:\n",
                "            probs = np.array(probs, dtype=np.float64)\n",
                "            probs = probs / probs.sum()\n",
                "            next_token = np.random.choice(tokens, p=probs)\n",
                "        generated_tokens.append(next_token)\n",
                "    return ''.join(generated_tokens)\n"
            ]

            # Let's inspect the actual notebook cell content to adapt if needed
            cell_src = "".join(cell["source"])
            print("Original generate_text_from_ngram_model cell:")
            print(cell_src)

        # Task 4a: segment_encoded_sequence
        if "def segment_encoded_sequence" in source:
            print(f"Patching Task 4a (segment_encoded_sequence) in Cell {idx}...")
            cell_src = "".join(cell["source"])
            print("Original segment_encoded_sequence cell:")
            print(cell_src)

        # Task 4b: create_training_sequences
        if "def create_training_sequences" in source:
            print(f"Patching Task 4b (create_training_sequences) in Cell {idx}...")
            cell_src = "".join(cell["source"])
            print("Original create_training_sequences cell:")
            print(cell_src)

    # Let's save a python script dump of the notebook to analyze all helper functions
    py_code = []
    for idx, cell in enumerate(nb.get("cells", [])):
        if cell.get("cell_type") == "code":
            py_code.append(f"# === Cell {idx} ===")
            py_code.append("".join(cell.get("source", [])))
            py_code.append("\n")

    with open("notebook_dump.py", "w", encoding="utf-8") as f:
        f.write("\n".join(py_code))

    print("\nSaved notebook cells to notebook_dump.py for analysis.")

if __name__ == "__main__":
    main()
