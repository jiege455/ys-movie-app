"""Check for code swallowed by // comments in api.dart"""
import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Check every line for // that's NOT /// (doc comment)
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    
    # Find position of // that's not ///
    for m in re.finditer(r'(?<!/)//(?!/)', stripped):
        before = stripped[:m.start()]
        after_comment = stripped[m.end():]
        
        # If there's code after the //, it's swallowed
        if after_comment.strip() and not after_comment.strip().startswith('//'):
            # Check if after_comment looks like Dart code (contains keywords or braces)
            if re.search(r'\b(void|Future|bool|int|String|Map|List|Widget|class|return|if|for|while|switch|try|catch|async|await|setState|build|context|State|final|const|var|dynamic)\b|[{}();]', after_comment):
                if 'import' not in before and 'http' not in before:
                    print(f'*** LINE {i}: CODE SWALLOWED BY COMMENT ***')
                    print(f'  Before //: {before[-80:]}')
                    print(f'  After //: {after_comment[:80]}')
                    print()

    # Also check for lines that start with // but contain code patterns (classic "comment swallowing code")
    if re.match(r'^\s*//[^/]', stripped):
        rest = stripped.lstrip('/').strip()
        if re.search(r'\b(void|Future|bool|int|String|Map|List|Widget|class|return|if\(|for\(|while\(|switch\(|try\{|catch\(|async|await)\b|[{}();]\s*$', rest):
            # Make sure it's not just a comment about these keywords
            if re.search(r'[{}();]', rest):
                print(f'*** LINE {i}: POSSIBLE CODE IN COMMENT ***')
                print(f'  Content: {stripped[:200]}')
                print()

print('Scan complete.')