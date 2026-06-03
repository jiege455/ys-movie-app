import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.split('\n')

# Method 1: Process full content
content_ns = content
content_ns = re.sub(r"'''[^']*'''", "''", content_ns)
content_ns = re.sub(r'"""[^"]*"""', '""', content_ns)
content_ns = re.sub(r"'[^']*'", "''", content_ns)
content_ns = re.sub(r'"[^"]*"', '""', content_ns)
content_ns = re.sub(r"r'[^']*'", "''", content_ns)
content_ns = re.sub(r'r"[^"]*"', '""', content_ns)
content_ns = re.sub(r'//[^\n]*', '', content_ns)
content_ns = re.sub(r'/\*.*?\*/', '', content_ns, flags=re.DOTALL)

print(f'Full content: lines={len(lines)}, {{{content_ns.count("{")}}}, }}}{content_ns.count("}")}, diff={content_ns.count("{")-content_ns.count("}")}')

# Method 2: Process line by line (like check_braces.py)  
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

print(f'Line-by-line: final depth={depth}, opens={sum(line_ns.count("{") for line_ns in [re.sub(r"//[^\n]*", "", re.sub(r"''''''[^'']*''''''", "''", re.sub(r''"""[^"]*"""'', '""', re.sub(r"'[^']*'", "''", re.sub(r'"[^"]*"', '""', re.sub(r"r'[^']*'", "''", re.sub(r'r"[^"]*"', '""', line))))) for line in lines]))}, closes={sum(re.sub(r"//[^\n]*", "", re.sub(r"''''''[^'']*''''''", "''", re.sub(r''"""[^"]*"""'', '""', re.sub(r"'[^']*'", "''", re.sub(r'"[^"]*"', '""', re.sub(r"r'[^']*'", "''", re.sub(r'r"[^"]*"', '""', line)))))).count("}") for line in lines)}')

# WARNING: The above is messy. Let me just do a simple line-by-line depth track
depth = 0
for i, line in enumerate(lines, 1):
    line_ns = re.sub(r"'''[^']*'''", "''", line)
    line_ns = re.sub(r'"""[^"]*"""', '""', line_ns)
    line_ns = re.sub(r"'[^']*'", "''", line_ns)
    line_ns = re.sub(r'"[^"]*"', '""', line_ns)
    line_ns = re.sub(r"r'[^']*'", "''", line_ns)
    line_ns = re.sub(r'r"[^"]*"', '""', line_ns)
    line_ns = re.sub(r'//[^\n]*', '', line_ns)
    opens = line_ns.count('{')
    closes = line_ns.count('}')
    depth += opens - closes
    if depth < 0:
        print(f'DEPTH NEGATIVE at line {i}! depth={depth}')

total_opens = sum(re.sub(r"//[^\n]*", "", re.sub(r"r'[^']*'", "''", re.sub(r'r"[^"]*"', '""', re.sub(r"'[^']*'", "''", re.sub(r'"[^"]*"', '""', re.sub(r"'''[^']*'''", "''", re.sub(r'"""[^"]*"""', '""', line))))))).count('{') for line in lines)
total_closes = sum(re.sub(r"//[^\n]*", "", re.sub(r"r'[^']*'", "''", re.sub(r'r"[^"]*"', '""', re.sub(r"'[^']*'", "''", re.sub(r'"[^"]*"', '""', re.sub(r"'''[^']*'''", "''", re.sub(r'"""[^"]*"""', '""', line))))))).count('}') for line in lines)
print(f'Total opens: {total_opens}, Total closes: {total_closes}, Diff: {total_opens-total_closes}')
print(f'Final depth: {depth}')