import json
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

def translate_text(text):
    if not isinstance(text, str) or not text.strip() or '{' in text:
        # skip translating format strings like {{remote}} to avoid breaking them
        return text
    try:
        url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=tr&dt=t&q=" + urllib.parse.quote(text)
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read().decode('utf-8'))
        return "".join([x[0] for x in result[0]])
    except Exception as e:
        return text

def main():
    en_path = "c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/en.json"
    tr_path = "c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json"
    
    with open(en_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Flatten the dict to translate all strings
    paths = []
    
    def extract_paths(obj, current_path):
        if isinstance(obj, dict):
            for k, v in obj.items():
                extract_paths(v, current_path + [k])
        elif isinstance(obj, str):
            paths.append((current_path, obj))
    
    extract_paths(data, [])
    
    print(f"Found {len(paths)} strings to translate.")
    
    # Translate concurrently
    results = {}
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(translate_text, txt): path for path, txt in paths}
        for i, future in enumerate(futures):
            path = futures[future]
            try:
                translated = future.result()
                results[tuple(path)] = translated
            except Exception as e:
                results[tuple(path)] = paths[i][1]
    
    # Reconstruct
    for path, translated_val in results.items():
        ref = data
        for k in path[:-1]:
            ref = ref[k]
        ref[path[-1]] = translated_val

    if "guide" in data and "about" in data["guide"]:
        data["guide"]["about"]["github_repo"] = "kurbaga3131/atlantic"
        
    with open(tr_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()
