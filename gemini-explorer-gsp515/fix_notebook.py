import json
filepath = r'C:\Users\Quincy\Downloads\gemini-explorer-challenge (1).ipynb'
with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

for cell in data.get('cells', []):
    if cell.get('cell_type') == 'code':
        source = cell.get('source', [])
        new_source = []
        for line in source:
            if 'model_name=' in line:
                line = line.replace('gemini-2.5-flash', 'gemini-1.5-flash').replace('gemini-3.5-flash', 'gemini-1.5-flash')
            if 'model_id' in line and 'model=' in line:
                line = line.replace('model_id', '\"gemini-1.5-flash\"')
            new_source.append(line)
        cell['source'] = new_source

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=1)
print('Notebook updated successfully.')
