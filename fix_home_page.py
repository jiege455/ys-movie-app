import re

with open('ys_movie_app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix escaped string interpolation: \${v['id']} -> ${v['id']}
# But we need to be careful to only fix inside string literals

# Pattern 1: '\${v['id']}' -> '${v['id']}'
content = content.replace("'\${v['id']}'", "'${v['id']}'")

# Pattern 2: '\${v['score'] ?? 0}' -> '${v['score'] ?? 0}'
content = content.replace("'\${v['score'] ?? 0}'", "'${v['score'] ?? 0}'")

# Pattern 3: '\${v['year'] ?? \'\'}' -> '${v['year'] ?? \'\'}'
content = content.replace("'\${v['year'] ?? \'\'}'", "'${v['year'] ?? \'\'}'")

# Also fix print statements
content = content.replace("'\${recList.length} items'", "'${recList.length} items'")
content = content.replace("'\$e'", "'$e'")

with open('ys_movie_app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed home_page.dart")
