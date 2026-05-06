import os

base = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\widgets'

files_to_fix = [
    'slide_banner.dart',
    'custom_player_controls.dart',
    'cast_controls.dart',
    'cast_dialog.dart',
    'comment_item.dart',
]

replacements = [
    ('Colors.grey[800]', 'AppColors.darkElevated'),
    ('Colors.grey[200]', 'AppColors.slate200'),
    ('Colors.grey[100]', 'AppColors.slate100'),
    ('Colors.grey[300]', 'AppColors.slate300'),
    ('Colors.grey[400]', 'AppColors.slate400'),
    ('Colors.grey[600]', 'AppColors.slate600'),
    ('Colors.grey.withOpacity(0.5)', 'AppColors.slate400.withOpacity(0.5)'),
    ('Colors.grey.withOpacity(0.2)', 'AppColors.slate400.withOpacity(0.2)'),
    ('Colors.grey.withOpacity(0.3)', 'AppColors.slate400.withOpacity(0.3)'),
    ('Colors.grey.withOpacity(0.1)', 'AppColors.slate400.withOpacity(0.1)'),
    ('Colors.white70', 'AppColors.slate300'),
    ('Colors.white60', 'AppColors.slate400'),
    ('Colors.white54', 'AppColors.slate500'),
    ('Colors.white12', 'AppColors.slate700.withOpacity(0.12)'),
    ('Colors.white10', 'AppColors.slate700.withOpacity(0.1)'),
]

import re

for fname in files_to_fix:
    path = os.path.join(base, fname)
    if not os.path.exists(path):
        continue
    
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    for old, new in replacements:
        content = content.replace(old, new)
    
    # 替换单独的 Colors.grey
    content = re.sub(r'(?<!\w)Colors\.grey(?!\[)', 'AppColors.slate400', content)
    
    # 添加 AppColors 导入
    if '../theme/app_theme.dart' not in content and 'app_theme.dart' not in content:
        if "import 'package:flutter/material.dart';" in content:
            content = content.replace(
                "import 'package:flutter/material.dart';",
                "import 'package:flutter/material.dart';\nimport '../theme/app_theme.dart';"
            )
    
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated: {fname}')
    else:
        print(f'No changes: {fname}')

print('All done!')
