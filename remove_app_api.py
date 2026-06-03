import re

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove app_api.php calls from getFiltered() - lines 2144-2175 approximately
# Find and remove the app_api.php block in getFiltered
pattern = r"""    // 2\. 尝试 app_api\.php 自定义接口
    final customApiUrl = '\$\{rootUrl\}app_api\.php';
    try \{
       final params = \{
         'ac': 'list',
         'pg': page,
         'pagesize': limit,
         'by': orderby,
       \};
       if \(typeId != null\) params\['t'\] = typeId;
       if \(year != null && year != '全部'\) params\['year'\] = year;
       if \(area != null && area != '全部'\) params\['area'\] = area;
       if \(lang != null && lang != '全部'\) params\['lang'\] = lang;
       if \(clazz != null && clazz != '全部'\) params\['class'\] = clazz;
       
       final resp = await _dio\.get\(customApiUrl, queryParameters: params\);
       if \(resp\.statusCode == 200 && resp\.data is Map && resp\.data\['code'\] == 1\) \{
          final list = \(resp\.data\['list'\] as List\?\) \?\? \[\];
          final results = list\.map\(\(item\) \{
            final v = item as Map<String, dynamic>;
            final dynamic rawTypeId = v\['type_id'\] \?\? v\['type_id_1'\] \?\? v\['type'\];
            final int parsedTypeId = int\.tryParse\('\$rawTypeId'\) \?\? 0;
            return \{
              'id': '\$\{v\['vod_id'\]\}',
              'title': v\['vod_name'\] \?\? '',
              'poster': _fixUrl\(v\['vod_pic'\]\),
              'type_id': parsedTypeId,
              'score': double\.tryParse\('\$\{v\['vod_score'\] \?\? 0\}'\) \?\? 0\.0,
              'year': '\$\{v\['vod_year'\] \?\? ''\}',
              'overview': v\['vod_remarks'\] \?\? '',
              'area': v\['vod_area'\] \?\? '',
              'lang': v\['vod_lang'\] \?\? '',
              'class': v\['type_name'\] \?\? v\['vod_class'\] \?\? '',
              'actor': v\['vod_actor'\] \?\? '',
              'play_url': v\['vod_play_url'\] \?\? '',
            \};
          \}\)\.toList\(\);
          
          if \(results\.isNotEmpty\) \{
            final validated = _filterByTypeId\(typeId, results\);
            _categoryCache\.set\(cacheKey, validated\);
            return validated;
          \}
       \}
    \} catch \(_\) \{\}

"""

# Simple approach: just replace the specific block
old_block = """    // 2. 尝试 app_api.php 自定义接口
    final customApiUrl = '${rootUrl}app_api.php';
    try {
       final params = {
         'ac': 'list',
         'pg': page,
         'pagesize': limit,
         'by': orderby,
       };
       if (typeId != null) params['t'] = typeId;
       if (year != null && year != '全部') params['year'] = year;
       if (area != null && area != '全部') params['area'] = area;
       if (lang != null && lang != '全部') params['lang'] = lang;
       if (clazz != null && clazz != '全部') params['class'] = clazz;
       
       final resp = await _dio.get(customApiUrl, queryParameters: params);
       if (resp.statusCode == 200 && resp.data is Map && resp.data['code'] == 1) {
          final list = (resp.data['list'] as List?) ?? [];
          final results = list.map((item) {
            final v = item as Map<String, dynamic>;
            final dynamic rawTypeId = v['type_id'] ?? v['type_id_1'] ?? v['type'];
            final int parsedTypeId = int.tryParse('$rawTypeId') ?? 0;
            return {
              'id': '${v['vod_id']}',
              'title': v['vod_name'] ?? '',
              'poster': _fixUrl(v['vod_pic']),
              'type_id': parsedTypeId,
              'score': double.tryParse('${v['vod_score'] ?? 0}') ?? 0.0,
              'year': '${v['vod_year'] ?? ''}',
              'overview': v['vod_remarks'] ?? '',
              'area': v['vod_area'] ?? '',
              'lang': v['vod_lang'] ?? '',
              'class': v['type_name'] ?? v['vod_class'] ?? '',
              'actor': v['vod_actor'] ?? '',
              'play_url': v['vod_play_url'] ?? '',
            };
          }).toList();
          
          if (results.isNotEmpty) {
            final validated = _filterByTypeId(typeId, results);
            _categoryCache.set(cacheKey, validated);
            return validated;
          }
       }
    } catch (_) {}

"""

new_block = """    // 2. 杰哥：统一使用 jgappapi 插件接口，移除 app_api.php 调用

"""

if old_block in content:
    content = content.replace(old_block, new_block)
    print('✅ Removed app_api.php from getFiltered()')
else:
    print('⚠️ Block not found in getFiltered()')

with open(r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib\services\api.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
