import os

def replace_in_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        new_content = content.replace('"atlantic ', '"atlantic ').replace("'atlantic ", "'atlantic ").replace(' atlantic ', ' atlantic ').replace('exec atlantic', 'exec atlantic')
        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print('Updated', filepath)
    except Exception as e:
        pass

for d in ['compositors', 'src/scripts', 'nix']:
    for r, ds, fs in os.walk(d):
        for f in fs: replace_in_file(os.path.join(r, f))

replace_in_file('README.md')
replace_in_file('flake.nix')
