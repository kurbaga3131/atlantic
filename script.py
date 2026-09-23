import sys
content = open('install/modules/ui.sh', 'r', encoding='utf-8').read()
ascii_art = open('install_ascii.txt', 'r', encoding='utf-8').read().rstrip()

start_marker = '    else\n        cat << "EOF"\n'
end_marker = '\nEOF\n    fi\n    printf "%s'

start_idx = content.find(start_marker, content.rfind('draw_completion_screen()'))
if start_idx != -1:
    end_idx = content.find(end_marker, start_idx)
    if end_idx != -1:
        new_content = content[:start_idx + len(start_marker)] + ascii_art + content[end_idx:]
        open('install/modules/ui.sh', 'w', encoding='utf-8').write(new_content)
        print('SUCCESS')
    else:
        print('END NOT FOUND')
else:
    print('START NOT FOUND')
