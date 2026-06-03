"""Deep scan api.dart for any encoding or syntax issues"""
import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'Total lines: {len(lines)}')

# Check for lines that look suspicious
for i, line in enumerate(lines, 1):
    stripped = line.rstrip('\n\r')
    
    # Check for non-printable characters (excluding normal whitespace)
    for j, ch in enumerate(stripped):
        if ord(ch) < 32 and ch not in '\t\r\n':
            print(f'Line {i}: Non-printable char U+{ord(ch):04X} at pos {j}')
            print(f'  Content: {stripped[:200]}')
        # Check for replacement character
        if ch == '\ufffd' or ch == '\u0000':
            print(f'Line {i}: Suspicious char at pos {j}: {repr(stripped[max(0,j-20):j+20])}')
    
    # Check for lines that start with // but contain code keywords
    if stripped.strip().startswith('//') and not stripped.strip().startswith('///'):
        rest = stripped.strip()[2:]
        # If the comment line contains method signatures
        if re.search(r'(Future|void|bool|int|String|Map|List|Widget)\s+(get\s+)?\w+\s*[\(<{]', rest):
            print(f'Line {i}: Possible code in comment: {stripped[:200]}')

# Check line ending consistency
crlf = sum(1 for l in lines if l.endswith('\r\n'))
lf = sum(1 for l in lines if l.endswith('\n') and not l.endswith('\r\n'))
print(f'\nLine endings: CRLF={crlf}, LF={lf}')

# Check for Dart method definitions that might have issues
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    # Check for lines with "??" that might be corrupted
    if '??' in stripped and not re.search(r'\?\?\s*\w', stripped) and not '???' in stripped:
        # Check for potential double encoding issue
        pass

print('\nDeep scan complete.')
