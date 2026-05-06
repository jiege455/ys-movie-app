import sys

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Replace lines 1629-1649 (0-indexed: 1628-1648) - remove app_api.php call
new_lines = lines[:1628]  # Keep lines 1-1628

new_code = """      // 1. 杰哥：统一使用 jgappapi 插件接口，移除 app_api.php 调用
      // 原因：app_api.php 在宝塔环境下可能因 open_basedir 限制无法工作
      // 直接使用 getFiltered 兜底获取最新影片
"""
new_lines.append(new_code)
new_lines.extend(lines[1649:])  # Add lines 1650+

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Done - removed app_api.php from getRecommended()')
