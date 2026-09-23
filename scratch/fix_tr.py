import json

with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "r", encoding="utf-8") as f:
    data = json.load(f)

def fix_dict(d):
    for k, v in d.items():
        if isinstance(v, str):
            if v == "Serpantin":
                d[k] = "atlantic"
            if v == "serpantin":
                d[k] = "atlantic"
        elif isinstance(v, dict):
            fix_dict(v)

fix_dict(data)

# Fix equalizer presets
if "music" in data and "presets" in data["music"]:
    data["music"]["presets"]["flat"] = "Flat"
    data["music"]["presets"]["bass"] = "Bass"
    data["music"]["presets"]["treble"] = "Treble"
    data["music"]["presets"]["vocal"] = "Vocal"
    data["music"]["presets"]["pop"] = "Pop"
    data["music"]["presets"]["rock"] = "Rock"
    data["music"]["presets"]["jazz"] = "Jazz"
    data["music"]["presets"]["classic"] = "Classic"
    data["music"]["presets"]["custom"] = "Custom"

with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
