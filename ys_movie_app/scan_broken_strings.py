import os

def scan_broken_strings(filepath):
    """Check for broken single-quoted strings (missing closing quote due to encoding corruption)"""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    lines = data.split(b'\n')
    broken = []
    
    for i, line in enumerate(lines):
        if not line:
            continue
        quote_count = line.count(b"'")
        if quote_count == 0:
            continue
        try:
            text = line.decode('utf-8')
        except:
            broken.append((i + 1, 'UTF-8 decode error'))
            continue
        has_non_ascii = any(ord(c) > 127 for c in text)
        if has_non_ascii and quote_count % 2 == 1:
            stripped = text.strip()
            broken.append((i + 1, stripped[:100]))
    
    return broken

def main():
    dart_files = []
    for root, dirs, files in os.walk('lib'):
        for f in files:
            if f.endswith('.dart'):
                dart_files.append(os.path.join(root, f))
    
    total = 0
    for fp in sorted(dart_files):
        if 'api_backup' in fp:
            continue
        broken = scan_broken_strings(fp)
        if broken:
            print(f'\n=== {fp} ===')
            for ln, detail in broken:
                print(f'  Line {ln}: {detail}')
            total += len(broken)
    
    if total == 0:
        print('SCAN COMPLETE - No broken strings found')
    else:
        print(f'\nTotal broken strings: {total}')
        exit(1)

if __name__ == '__main__':
    main()
