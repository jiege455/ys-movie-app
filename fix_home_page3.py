import re

with open('ys_movie_app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the specific line: print('Home Page: getFiltered returned \${recList.length} items');
content = content.replace(
    "print('Home Page: getFiltered returned \\${recList.length} items');",
    "print('Home Page: getFiltered returned \${recList.length} items');"
)

# Fix catch block: print('Home Page: getFiltered failed: \$e');
content = content.replace(
    "print('Home Page: getFiltered failed: \\$e');",
    "print('Home Page: getFiltered failed: \$e');"
)

content = content.replace(
    "print('Home Page: Second fallback failed: \\$e');",
    "print('Home Page: Second fallback failed: \$e');"
)

with open('ys_movie_app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed print statements")
