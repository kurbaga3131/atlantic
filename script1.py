import re

c = open('install/modules/ui.sh', 'r', encoding='utf-8').read()
b1 = open('update_banner.txt', 'r', encoding='utf-8').read().rstrip() + '\n'
b2 = open('update_complete.txt', 'r', encoding='utf-8').read().rstrip() + '\n'

def replacer(match):
    replacer.count += 1
    if replacer.count == 1:
        return 'cat << "EOF"\n' + b1 + 'EOF'
    elif replacer.count == 3:
        return 'cat << "EOF"\n' + b2 + 'EOF'
    else:
        return match.group(0)
replacer.count = 0

new_c = re.sub(r'cat << "EOF"\n.*?EOF', replacer, c, flags=re.DOTALL)
open('install/modules/ui.sh', 'w', encoding='utf-8').write(new_c)
print('Done!')
