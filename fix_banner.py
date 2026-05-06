import sys

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Replace lines 806-831 (0-indexed: 805-830)
new_lines = lines[:805]  # Keep lines 1-805

new_code = """    // 插件/自定义接口不可用时，使用筛选接口近似"轮播"：取最新影片作为兜底
    // 杰哥修复：恢复兜底逻辑，防止首页轮播图为空导致白板
    try {
      final latest = await getFiltered(orderby: 'time', limit: 5);
      if (latest.isNotEmpty) {
        return latest.map((e) => {
          'id': e['id'],
          'title': e['title'],
          'poster': e['poster'],
          'type': e['type'] ?? '',
        }).toList();
      }
    } catch (e) {
      print('Banner fallback failed: \$e');
    }
    return [];
  }
"""
new_lines.append(new_code)
new_lines.extend(lines[831:])  # Add lines 832+

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('Done')
