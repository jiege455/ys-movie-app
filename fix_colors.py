import os

base = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib'

# 修复 home_page.dart
path = os.path.join(base, 'pages', 'home_page.dart')
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = [
    ('isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)', 'isDark ? AppColors.darkBackground : AppColors.slate50'),
    ('isDark ? const Color(0xFF1E293B) : Colors.white', 'isDark ? AppColors.darkCard : Colors.white'),
    ('isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)', 'isDark ? AppColors.slate700 : AppColors.slate200'),
    ('isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)', 'AppColors.slate400'),
    ('isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)', 'isDark ? AppColors.slate400 : AppColors.slate500'),
    ('isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)', 'isDark ? AppColors.slate300 : AppColors.slate700'),
    ('Colors.grey[300]!', 'AppColors.slate300'),
    ('Colors.grey[100]!', 'AppColors.slate100'),
    ('Colors.grey[800]', 'AppColors.darkElevated'),
    ('Colors.grey[200]', 'AppColors.slate200'),
    ('Colors.grey[400]', 'AppColors.slate400'),
    ('Colors.grey[600]', 'AppColors.slate600'),
    ('Colors.black54', 'AppColors.slate900.withOpacity(0.54)'),
]

for old, new in replacements:
    content = content.replace(old, new)

if '../theme/app_theme.dart' not in content:
    content = content.replace(
        "import '../services/theme_provider.dart';",
        "import '../services/theme_provider.dart';\nimport '../theme/app_theme.dart';"
    )

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('home_page.dart updated!')

# 修复 profile_page.dart 中的 Colors.grey
path2 = os.path.join(base, 'pages', 'profile_page.dart')
with open(path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

profile_replacements = [
    ('Colors.grey[200]', 'AppColors.slate200'),
    ('Colors.grey.withOpacity(0.5)', 'AppColors.slate400.withOpacity(0.5)'),
]

for old, new in profile_replacements:
    content2 = content2.replace(old, new)

if '../theme/app_theme.dart' not in content2:
    content2 = content2.replace(
        "import '../services/theme_provider.dart';",
        "import '../services/theme_provider.dart';\nimport '../theme/app_theme.dart';"
    )

with open(path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print('profile_page.dart updated!')

# 修复 ranking_page.dart 中的 Colors.grey
path3 = os.path.join(base, 'pages', 'ranking_page.dart')
with open(path3, 'r', encoding='utf-8') as f:
    content3 = f.read()

ranking_replacements = [
    ('Colors.grey[200]', 'AppColors.slate200'),
    ('Colors.grey', 'AppColors.slate400'),
]

for old, new in ranking_replacements:
    content3 = content3.replace(old, new)

if '../theme/app_theme.dart' not in content3:
    content3 = content3.replace(
        "import '../services/theme_provider.dart';",
        "import '../services/theme_provider.dart';\nimport '../theme/app_theme.dart';"
    )

with open(path3, 'w', encoding='utf-8') as f:
    f.write(content3)
print('ranking_page.dart updated!')

print('All done!')
