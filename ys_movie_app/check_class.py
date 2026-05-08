import re

def count_brackets(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove string literals first
    content = re.sub(r"'''[^']*'''", '', content)
    content = re.sub(r'"""[^"]*"""', '', content)
    content = re.sub(r"'[^']*'", "''", content)
    content = re.sub(r'"[^"]*"', '""', content)
    # Remove regex strings like r'...' and r"..."
    content = re.sub(r"r'[^']*'", "''", content)
    content = re.sub(r'r"[^"]*"', '""', content)
    # Remove // comments
    content = re.sub(r'//[^\n]*', '', content)
    # Remove /* */ comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    
    return {'{': content.count('{'), '}': content.count('}'), '(': content.count('('), ')': content.count(')')}

for fn in ['lib/services/api.dart', 'lib/services/api_backup.dart']:
    r = count_brackets(fn)
    print(f'{fn}:')
    print(f'  {{ = {r["{"]}, }} = {r["}"]}, diff = {r["{"] - r["}"]}')
    print(f'  ( = {r["("]}, ) = {r[")"]}, diff = {r["("] - r[")"]}')
