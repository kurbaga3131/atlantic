import json
import urllib.request
import urllib.parse
import time
import os

def translate_text(text):
    if not isinstance(text, str) or not text.strip():
        return text
    
    # Handle variables like {{variable}} or {variable} by temporarily replacing them if needed,
    # but Google Translate usually preserves {} brackets.
    
    url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&q=" + urllib.parse.quote(text)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = urllib.request.urlopen(req)
            result = json.loads(response.read().decode('utf-8'))
            translated = "".join([x[0] for x in result[0]])
            return translated
        except Exception as e:
            if attempt == max_retries - 1:
                print(f"Error translating '{text}': {e}")
                return text
            time.sleep(1)

def recursive_translate(obj):
    if isinstance(obj, dict):
        new_dict = {}
        for k, v in obj.items():
            new_dict[k] = recursive_translate(v)
        return new_dict
    elif isinstance(obj, list):
        return [recursive_translate(item) for item in obj]
    elif isinstance(obj, str):
        return translate_text(obj)
    else:
        return obj

def main():
    en_path = "c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/en.json"
    tr_path = "c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json"
    
    print("Loading English JSON...")
    with open(en_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    print("Translating to Turkish... (This might take a minute)")
    translated_data = recursive_translate(data)
    
    # Fix the author name that got overwritten
    if "guide" in translated_data and "about" in translated_data["guide"]:
        translated_data["guide"]["about"]["github_repo"] = "kurbaga3131/atlantic"
    
    print("Saving Turkish JSON...")
    with open(tr_path, "w", encoding="utf-8") as f:
        json.dump(translated_data, f, ensure_ascii=False, indent=2)
    
    print("Translation complete!")

if __name__ == "__main__":
    main()
