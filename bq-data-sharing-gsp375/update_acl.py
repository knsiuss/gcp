import json
import sys

def main():
    mode = sys.argv[1]  # "view" or "user"
    json_file = sys.argv[2]
    
    with open(json_file, 'r') as f:
        data = json.load(f)
        
    if "access" not in data:
        data["access"] = []
        
    if mode == "view":
        project_id = sys.argv[3]
        dataset_id = sys.argv[4]
        view_id = sys.argv[5]
        
        view_entry = {
            "view": {
                "projectId": project_id,
                "datasetId": dataset_id,
                "tableId": view_id
            }
        }
        
        # Check if already exists
        exists = False
        for entry in data["access"]:
            if "view" in entry:
                v = entry["view"]
                if v.get("projectId") == project_id and v.get("datasetId") == dataset_id and v.get("tableId") == view_id:
                    exists = True
                    break
        
        if not exists:
            data["access"].append(view_entry)
            print(f"Added authorized view entry: {project_id}:{dataset_id}.{view_id}")
            
    elif mode == "user":
        user_email = sys.argv[3]
        role = sys.argv[4]  # "READER"
        
        user_entry = {
            "role": role,
            "userByEmail": user_email
        }
        
        # Check if already exists
        exists = False
        for entry in data["access"]:
            if "userByEmail" in entry and entry.get("userByEmail") == user_email:
                entry["role"] = role  # Update role if exists
                exists = True
                break
                
        if not exists:
            data["access"].append(user_entry)
            print(f"Added user access entry for {user_email} with role {role}")
            
    with open(json_file, 'w') as f:
        json.dump(data, f, indent=2)

if __name__ == "__main__":
    main()
