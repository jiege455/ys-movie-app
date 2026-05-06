import re

with open('ys_movie_app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fix specific lines
for i, line in enumerate(lines):
    # Line 1382 (0-indexed: 1381)
    if "getFiltered returned" in line and "\\${recList.length}" in line:
        lines[i] = line.replace("\\${recList.length}", "${recList.length}")
        print(f"Fixed line {i+1}: {lines[i].strip()}")
    
    # Line 1394 (0-indexed: 1393)
    if "getFiltered failed" in line and "\\$e" in line:
        lines[i] = line.replace("\\$e", "$e")
        print(f"Fixed line {i+1}: {lines[i].strip()}")
    
    # Line 1415 (0-indexed: 1414)
    if "Second fallback failed" in line and "\\$e" in line:
        lines[i] = line.replace("\\$e", "$e")
        print(f"Fixed line {i+1}: {lines[i].strip()}")

with open('ys_movie_app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Done")
