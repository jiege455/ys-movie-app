import re

filepath = 'lib/pages/feedback_center_page.dart'

# Read raw bytes
with open(filepath, 'rb') as f:
    raw = f.read()

# Split by lines (0x0A)
lines_raw = raw.split(b'\n')

# Problem lines from CI errors
problem_lines = [35, 46, 61, 192, 201, 207, 286, 812, 924, 932, 941, 950]

for ln in problem_lines:
    idx = ln - 1
    if idx >= len(lines_raw):
        print(f'Line {ln}: OUT OF RANGE ({len(lines_raw)} lines total)')
        continue
    
    line_bytes = lines_raw[idx]
    # Find all 0x27 positions
    quote_pos = [j for j, b in enumerate(line_bytes) if b == 0x27]
    
    # Extract 10 bytes around each quote position
    print(f'\nLine {ln}: {len(quote_pos)} quotes, {len(line_bytes)} bytes')
    for qp in quote_pos:
        start = max(0, qp - 5)
        end = min(len(line_bytes), qp + 15)
        context = line_bytes[start:end]
        hex_str = ' '.join(f'{b:02x}' for b in context)
        printable = ''.join(chr(b) if 32 <= b < 127 else '.' for b in context)
        marker = ' ' * (qp - start) * 3 + '^^^'
        print(f'  Quote at byte {qp}:')
        print(f'    hex:  {hex_str}')
        print(f'    ascii:{printable}')
