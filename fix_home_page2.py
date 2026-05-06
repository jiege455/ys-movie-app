import re

with open('ys_movie_app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix remaining escaped string interpolation in print statements
# \${recList.length} -> ${recList.length}
content = content.replace("'\${recList.length} items'", "'${recList.length} items'")

# \$e -> $e  (but only in string literals, not in actual code)
# Replace the specific pattern in print/catch blocks
content = content.replace("'\$e'", "'$e'")
content = content.replace('"\$e"', '"$e"')

with open('ys_movie_app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed remaining escaped interpolations")
