from pathlib import Path
import json

SCRIPT_DIR = Path(__file__).parent
DATA_FILE_PATH = SCRIPT_DIR / "store.json"

with open(DATA_FILE_PATH, "r") as file:
    database = json.load(file)

# print (database)

# user_input = "  FOR  "
# clean_input = user_input.strip().lower()

# print(clean_input)
print("===================================================================================")
lang_filter = input("Choose a language (or leave blank for ALL): ").strip().lower()
rough_input = input("What do you want to find: ")
clean_input = rough_input.strip().lower().replace(" ", "_")   # Cleans up rough input to match dictionary formatting
index = database.get(clean_input)
# print(index)
print("-----------------------------------------------------------------------------------")

# isolate sub dictionaries from main dictionaries
concepts = database.get("concepts", {})
keyword_index = database.get("keyword_index", {})

# check concept block first incase index unupdated
found_data = concepts.get(clean_input)

# if not there check keyword
if not found_data:
    concept_key = keyword_index.get(clean_input)
    found_data = concepts.get(concept_key)

if found_data :
    print(f"=== {found_data.get('title')} ===")

    data_type = found_data.get("type")

    # Layout for Syntax
    if data_type == "syntax" :
        # Displays system/library prerequisites if they exist
        if found_data.get("requires_libraries") :
            print(f"(!) PREREQUISITES: {found_data.get('requires_libraries')}")
        if found_data.get("language_notes") :
            print(f"(i) NOTE: {found_data.get('language_notes')}")

        languages = found_data.get("languages", {})
        for lang, code in languages.items() :
            if lang_filter == "" or lang_filter==lang:
                print(f"\n[{lang.upper()}]")
                if isinstance(code, dict):
                    for action, snippet in code.items() :
                        print(f"    {action.capitalize()}: {snippet}")
                else:
                    print(code)

    # Layout for algorithms
    if data_type == "algorithm" :
        print(f"Description: {found_data.get('description')}\n")

        analysis = found_data.get("analysis", {})
        print(f"Time Complexity: {analysis.get('time_complexity')}")
        print(f"Space Complexity: {analysis.get('space_complexity')}")

        print("Use Cases: ")
        for case in analysis.get("use_cases", []) :
            print(f" - {case}")

        print("\nStrengths: ")
        for strenghts in analysis.get("strengths", []) :
            print(f" - {strenghts}")

        print("\nWeaknesses: ")
        for weakness in analysis.get("weaknesses", []) :
            print(f" - {weakness}")

        print("\nCode Implementations: ")
        languages = found_data.get("languages", {})
        for lang, code in languages.items():
            if lang_filter == "" or lang_filter==lang:
                print(f"[{lang.upper()}]\n{code}\n")      
else :
    print("Keyword not found in reference journal.\n")

print("===================================================================================")


