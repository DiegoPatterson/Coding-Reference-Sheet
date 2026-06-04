from pathlib import Path
import json

SCRIPT_DIR = Path(__file__).parent
DATA_FILE_PATH = SCRIPT_DIR / "store.json"

with open(DATA_FILE_PATH, "r") as file:
    database = json.load(file)

print("===================================================================================")
lang_filter = input("Choose a language (or leave blank for ALL): ").strip().lower()
rough_input = input("What do you want to find: ")
print("-----------------------------------------------------------------------------------")


def normalize_query(text):
    return " ".join(text.strip().lower().replace("-", " ").replace("/", " ").split())


def normalize_key(text):
    return normalize_query(text).replace(" ", "_")


def build_search_blob(concept_key, concept_data):
    parts = [concept_key, concept_data.get("title", ""), concept_data.get("type", "")]

    for field_name in ("aliases", "search_terms", "query_languages"):
        field_value = concept_data.get(field_name, [])
        if isinstance(field_value, str):
            parts.append(field_value)
        elif isinstance(field_value, dict):
            parts.extend(str(key) for key in field_value.keys())
            parts.extend(str(value) for value in field_value.values() if isinstance(value, str))
        else:
            parts.extend(str(item) for item in field_value)

    parts.extend(str(language_name) for language_name in concept_data.get("languages", {}).keys())
    return normalize_query(" ".join(parts))


def find_concept(database, raw_query):
    concepts = database.get("concepts", {})
    keyword_index = database.get("keyword_index", {})
    clean_key = normalize_key(raw_query)

    if clean_key in concepts:
        return concepts.get(clean_key)

    linked_key = keyword_index.get(clean_key)
    if linked_key:
        return concepts.get(linked_key)

    normalized_query = normalize_query(raw_query)
    if not normalized_query:
        return None

    query_tokens = normalized_query.split()
    for concept_key, concept_data in concepts.items():
        search_blob = build_search_blob(concept_key, concept_data)
        if all(token in search_blob for token in query_tokens):
            return concept_data

    for concept_key, concept_data in concepts.items():
        search_blob = build_search_blob(concept_key, concept_data)
        if normalized_query in search_blob:
            return concept_data

    return None


def format_label(text):
    return text.replace("_", " ").title()


# isolate sub dictionaries from main dictionaries
concepts = database.get("concepts", {})
keyword_index = database.get("keyword_index", {})

found_data = find_concept(database, rough_input)

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
        if found_data.get("query_languages") :
            print(f"(i) QUERY LANGUAGES: {', '.join(found_data.get('query_languages'))}")

        languages = found_data.get("languages", {})
        for lang, code in languages.items() :
            if lang_filter == "" or lang_filter==lang:
                print(f"\n[{lang.upper()}]")
                if isinstance(code, dict):
                    for action, snippet in code.items() :
                        print(f"    {format_label(action)}: {snippet}")
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


