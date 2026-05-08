import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

content = ''.join(lines)

# Remove strings and comments
content_ns = content
content_ns = re.sub(r"'''[^']*'''", "''", content_ns)
content_ns = re.sub(r'"""[^"]*"""', '""', content_ns)
content_ns = re.sub(r"'[^']*'", "''", content_ns)
content_ns = re.sub(r'"[^"]*"', '""', content_ns)
content_ns = re.sub(r"r'[^']*'", "''", content_ns)
content_ns = re.sub(r'r"[^"]*"', '""', content_ns)
content_ns = re.sub(r'//[^\n]*', '', content_ns)
content_ns = re.sub(r'/\*.*?\*/', '', content_ns, flags=re.DOTALL)

print(f'Total lines: {len(lines)}')
print(f'Brace {{: {content_ns.count("{")}')
print(f'Brace }}: {content_ns.count("}")}')
print(f'Diff: {content_ns.count("{") - content_ns.count("}")}')

# Track line-by-line bracket depth
depth = 0
for i, line in enumerate(lines, 1):
    line_ns = line
    line_ns = re.sub(r"'''[^']*'''", "''", line_ns)
    line_ns = re.sub(r'"""[^"]*"""', '""', line_ns)
    line_ns = re.sub(r"'[^']*'", "''", line_ns)
    line_ns = re.sub(r'"[^"]*"', '""', line_ns)
    line_ns = re.sub(r"r'[^']*'", "''", line_ns)
    line_ns = re.sub(r'r"[^"]*"', '""', line_ns)
    line_ns = re.sub(r'//[^\n]*', '', line_ns)
    
    opens = line_ns.count('{')
    closes = line_ns.count('}')
    depth += opens - closes
    if depth < 2 and i > 100:
        print(f'Line {i}: depth={depth} (opens={opens}, closes={closes}) => {line.rstrip()[:120]}')
        if depth < 0:
            print('*** DEPTH WENT NEGATIVE ***')
            break

print(f'\nFinal depth: {depth}')
