import json
filepath = r'C:\Users\Quincy\Downloads\gemini-explorer-challenge (1).ipynb'
with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

for cell in data.get('cells', []):
    if cell.get('cell_type') == 'code':
        source = cell.get('source', [])
        new_source = []
        for line in source:
            if 'GenerativeModel(model_name=' in line:
                new_source.append('from vertexai.generative_models import GenerativeModel, Part\n')
            new_source.append(line)
        cell['source'] = new_source

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=1)
print('Notebook imports updated successfully.')
