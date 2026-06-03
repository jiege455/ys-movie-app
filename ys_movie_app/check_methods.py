"""Analyze api.dart bracket depth with context"""
import re

filepath = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def strip_line(line):
    """Remove strings and comments, keep brackets"""
    result = line
    result = re.sub(r"'''[^']*'''", "''", result)
    result = re.sub(r'"""[^"]*"""', '""', result)
    result = re.sub(r"'[^']*'", "''", result)
    result = re.sub(r'"[^"]*"', '""', result)
    result = re.sub(r"r'[^']*'", "''", result)
    result = re.sub(r'r"[^"]*"', '""', result)
    result = re.sub(r'//[^\n]*', '', result)
    return result

# Track class body context
depth = 0
class_depth = 0  # 1 when inside MacApi class
class_start = None
class_end = None
brace_stack = []  # Track what each brace was for

for i, line in enumerate(lines, 1):
    stripped = strip_line(line)
    opens = stripped.count('{')
    closes = stripped.count('}')
    prev_depth = depth
    depth += opens - closes
    
    # Track MacApi class specifically
    if 'class MacApi' in strip_line(line) and 'class _' not in strip_line(line):
        if class_start is None:
            class_start = i
            print(f'MacApi class starts at line {i}')
    
    if class_start is not None and class_end is None:
        if depth < 1:
            class_end = i
            print(f'MacApi class ends at line {i} (depth={depth})')
    
    # Track methods defined around the area
    method_match = re.search(r'(Future|void|bool|int|String|Map|List|Widget)\s+(get\s+)?(\w+)\s*[\(<{]', strip_line(line))
    if method_match and depth == 1 and class_start is not None:
        name = method_match.group(3)
        # Check if it's one of the "missing" methods
        missing = {'getUserVipCenter', 'buyVip', 'getUserPointsLogs', 'watchRewardAd', 
                   'getInviteLogs', 'getUserInfoSummary', 'deleteFavByVodId', 'getFavs',
                   'getUserName', 'modifyUserNickName', 'modifyPassword', 'logout'}
        if name in missing:
            print(f'  *** Found "missing" method {name} at line {i} (depth={depth}, class_depth state: {"inside" if class_start and not class_end else "outside"})')

print(f'\nFinal: depth={depth}, class_start={class_start}, class_end={class_end}')
