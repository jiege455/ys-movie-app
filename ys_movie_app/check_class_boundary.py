"""Check if any methods might be outside the MacApi class"""
import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

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

# Now track depth for each line
lines = content.split('\n')
ns_lines = content_ns.split('\n')

depth = 0
class_depth_start = -1
class_depth_end = -1

for i, (orig, ns) in enumerate(zip(lines, ns_lines), 1):
    opens = ns.count('{')
    closes = ns.count('}')
    depth += opens - closes
    
    # Track MacApi class depth
    if 'class MacApi' in ns:
        class_depth_start = depth
        print(f'Line {i}: MacApi class starts at depth {depth} (opens={opens}, closes={closes})')
    
    # If depth drops below class_depth_start, class has ended
    if class_depth_start > 0 and depth < class_depth_start:
        if class_depth_end < 0:
            class_depth_end = depth
            print(f'Line {i}: MacApi class ends at depth {depth} (opens={opens}, closes={closes})')
            print(f'  Content: {orig.strip()[:120]}')

print(f'\nFinal depth: {depth}')
print(f'Class depth start: {class_depth_start}')
print(f'Class depth end boundary: {class_depth_end}')

# Now specifically check for any code OUTSIDE the class (depth 0)
depth = 0
for i, (orig, ns) in enumerate(zip(lines, ns_lines), 1):
    opens = ns.count('{')
    closes = ns.count('}')
    
    if depth == 0 and i > 100:
        stripped = orig.strip()
        if stripped and not stripped.startswith('//') and not stripped.startswith('/*'):
            # Check if this looks like code
            if re.match(r'^(import|class|@|Future|void|bool|int|String|Map|List|Widget|final|const|static|typedef|enum|mixin|extension|part)\b', stripped):
                print(f'Line {i} (depth 0): CODE OUTSIDE CLASS: {stripped[:150]}')
    
    depth += opens - closes