import os
import re

BASE = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib'

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_file(path, replacements):
    content = read_file(path)
    for old, new in replacements:
        content = content.replace(old, new)
    write_file(path, content)
    print(f"Fixed: {os.path.basename(path)}")

def main():
    # 1. custom_player_controls.dart - remove const before AppColors.success.withOpacity
    fix_file(os.path.join(BASE, 'widgets', 'custom_player_controls.dart'), [
        ("const AppColors.success.withOpacity(0.5)", "AppColors.success.withOpacity(0.5)"),
        ("const AppColors.success.withOpacity(0.4)", "AppColors.success.withOpacity(0.4)"),
    ])
    
    # 2. feedback_center_page.dart - fix truncated Chinese characters
    fix_file(os.path.join(BASE, 'pages', 'feedback_center_page.dart'), [
        # Line 4-7: header comments
        ("/// 创建日期�?025-12-28", "/// 创建日期：2025-12-28"),
        ("/// 说明：反馈报错、求片找片、消息中心（系统公告与个人消息）页面合集�?", "/// 说明：反馈报错、求片找片、消息中心（系统公告与个人消息）页面合集"),
        ("/// by：杰�?  qq�?711793818", "/// by：杰哥  qq：2711793818"),
        # Line 16-17: class comments  
        ("/// 作用：包含反馈、求片和消息中心的页面集�?", "/// 作用：包含反馈、求片和消息中心的页面集合"),
        ("/// 解释：这里打包了"反馈报错"、"求片找片"、"消息中心"三个功能页�?", "/// 解释：这里打包了"反馈报错"、"求片找片"、"消息中心"三个功能页面"),
        # Line 36: initState text
        ("_contentCtrl.text = '【视频报错】\n影片�?{widget.vodName}\nID�?{widget.vodId}\n问题描述�?;", "_contentCtrl.text = '【视频报错】\n影片：${widget.vodName}\nID：${widget.vodId}\n问题描述：';"),
        # Line 42: submit comment
        ("/// 解释：点"提交反馈"时把内容发给服务器�?", "/// 解释：点"提交反馈"时把内容发给服务器"),
        # Line 47: snackbar text
        (".showSnackBar(const SnackBar(content: Text('请输入反馈内�?)));", ".showSnackBar(const SnackBar(content: Text('请输入反馈内容')));"),
        # Line 54: login check comment
        ("// 检查登�?", "// 检查登录"),
        # Line 62: filter word
        (".showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修�?)));", ".showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修改')));"),
        # Line 111: tips text
        ("'如遇播放卡顿、资源失效或有功能建议，请在此留言，我们会尽快处理�?", "'如遇播放卡顿、资源失效或有功能建议，请在此留言，我们会尽快处理'"),
        # Line 170: RequestMoviePage comment
        ("/// 作用：求片页面，把找不到的影片名称提交给后台", "/// 作用：求片页面，把找不到的影片名称提交给后台"),
        ("/// 解释：想看的片子这里报给后台，让站长帮你找�?", "/// 解释：想看的片子这里报给后台，让站长帮你找"),
        # Line 187: submit comment
        ("/// 解释：把片名和备注发到服务器�?", "/// 解释：把片名和备注发到服务器"),
        # Line 193: snackbar
        (".showSnackBar(const SnackBar(content: Text('请输入片�?)));", ".showSnackBar(const SnackBar(content: Text('请输入片名')));"),
        # Line 199: login check
        ("// 检查登�?", "// 检查登录"),
        (".showSnackBar(const SnackBar(content: Text('请先登录后提交求�?)));", ".showSnackBar(const SnackBar(content: Text('请先登录后提交求片')));"),
        # Line 208: filter word
        (".showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修�?)));", ".showSnackBar(const SnackBar(content: Text('内容包含敏感词，请修改')));"),
        # Line 258: tips text
        ("'想看的片子找不到？告诉我片名，站长帮你找！\n提交后请留意消息中心的"求片回复"�?", "'想看的片子找不到？告诉我片名，站长帮你找！\n提交后请留意消息中心的"求片回复"'"),
        # Line 280: hint text
        ("hintText: '准确的片名更容易找到�?", "hintText: '准确的片名更容易找到'"),
        # Line 287: label text
        ("Text('备注说明（选填�?", "Text('备注说明（选填）'"),
        # Line 304: hint text
        ("hintText: '例如：希望能�?K画质、国语配音、或者具体哪一�?..',", "hintText: '例如：希望能有4K画质、国语配音、或者具体哪一集..'"),
        # Line 335: MessageCenterPage comment
        ("/// 作用：消息中心，包括系统公告和个人消�?", "/// 作用：消息中心，包括系统公告和个人消息"),
        ("/// 解释：这里能看到后台发的公告和对你反�?求片的回复�?", "/// 解释：这里能看到后台发的公告和对你反馈、求片的回复"),
        # Line 388: NoticeListTab comment
        ("/// 作用：系统公�?Tab", "/// 作用：系统公告Tab"),
        ("/// 解释：展示站长在后台发的公告�?", "/// 解释：展示站长在后台发的公告"),
        # Line 403: load comment
        ("/// 解释：向服务器拉取公告数据�?", "/// 解释：向服务器拉取公告数据"),
        # Line 518: UserNoticeTab comment
        ("/// 作用：个人消�?Tab（反�?求片回复�?", "/// 作用：个人消息Tab（反馈、求片回复）"),
        ("/// 解释：后台对你提交的反馈、求片的回复都在这里�?", "/// 解释：后台对你提交的反馈、求片的回复都在这里"),
        # Line 534: scroll controller comment
        ("// 分页与滚动控�?", "// 分页与滚动控制"),
        # Line 548: scroll listener comment
        ("// 监听滚动，靠近底部自动加载更�?", "// 监听滚动，靠近底部自动加载更多"),
        # Line 577: loadAll comment
        ("/// 作用：同时拉取反馈和求片的消�?", "/// 作用：同时拉取反馈和求片的消息"),
        ("/// 解释：一次性从服务器把两类消息都取回来�?", "/// 解释：一次性从服务器把两类消息都取回来"),
        # Line 583: reset state comment
        ("// 重置分页状�?", "// 重置分页状态"),
        # Line 600: loadMoreSuggest comment
        ("/// 作用：加载更多"反馈回复�?", "/// 作用：加载更多"反馈回复""),
        ("/// 解释：向后端请求下一页反馈回复并追加到列表�?", "/// 解释：向后端请求下一页反馈回复并追加到列表"),
        # Line 624: loadMoreFind comment
        ("/// 作用：加载更多"求片回复�?", "/// 作用：加载更多"求片回复""),
        ("/// 解释：向后端请求下一页求片回复并追加到列表�?", "/// 解释：向后端请求下一页求片回复并追加到列表"),
        # Line 690: buildList comment
        ("/// 作用：渲染一类消息列�?", "/// 作用：渲染一类消息列表"),
        ("/// 解释：把某一类消息按列表方式显示出来�?", "/// 解释：把某一类消息按列表方式显示出来"),
        # Line 730: loading text
        ("loadingMore ? '加载�?..' : '已到底部'", "loadingMore ? '加载中...' : '已到底部'"),
        # Line 759: status text
        ("hasReply ? '管理员已回复' : '待处�?", "hasReply ? '管理员已回复' : '待处理'"),
    ])
    
    # 3. vod_list_page.dart - fix truncated Chinese
    fix_file(os.path.join(BASE, 'pages', 'vod_list_page.dart'), [
        ("/// 创建日期�?025-12-28", "/// 创建日期：2025-12-28"),
        ("/// 说明：展示某分类下的影片列表，支持多选管理（收藏、下载、删除�?", "/// 说明：展示某分类下的影片列表，支持多选管理（收藏、下载、删除）"),
        ("/// by：杰�?  qq�?711793818", "/// by：杰哥  qq：2711793818"),
        ("/// 作用：影片列表页，带多选管理功能（收藏、下载、删除�?", "/// 作用：影片列表页，带多选管理功能（收藏、下载、删除）"),
        ("/// 解释：从分类点进来看到的影片列表，可以批量操作�?", "/// 解释：从分类点进来看到的影片列表，可以批量操作"),
        ("/// 解释：向后端请求影片列表，支持分页�?", "/// 解释：向后端请求影片列表，支持分页"),
        ("/// 解释：多选模式下底部弹出的操作菜�?", "/// 解释：多选模式下底部弹出的操作菜单"),
        ("tooltip: _selectMode ? '退出多�? : '多�?", "tooltip: _selectMode ? '退出多选' : '多选'"),
    ])
    
    # 4. history_page.dart - fix truncated Chinese
    fix_file(os.path.join(BASE, 'pages', 'history_page.dart'), [
        ("/// 创建日期�?025-12-28", "/// 创建日期：2025-12-28"),
        ("/// 说明：观看历史记录页面，支持长按多选删除和批量清�?", "/// 说明：观看历史记录页面，支持长按多选删除和批量清空"),
        ("/// by：杰�?  qq�?711793818", "/// by：杰哥  qq：2711793818"),
        ("/// 作用：观看历史页面，支持长按多选删除和批量清�?", "/// 作用：观看历史页面，支持长按多选删除和批量清空"),
        ("/// 解释：你在这里能看到自己看过哪些片子，长按可以多选删�?", "/// 解释：你在这里能看到自己看过哪些片子，长按可以多选删除"),
        ("/// 解释：从服务器拉取历史记录，支持分页�?", "/// 解释：从服务器拉取历史记录，支持分页"),
        ("/// 解释：向后端请求删除选中的历史记�?", "/// 解释：向后端请求删除选中的历史记录"),
        ("/// 解释：多选模式下底部弹出的操作菜�?", "/// 解释：多选模式下底部弹出的操作菜单"),
        ("'上次观看�?{_formatTime(item['time'])}'", "'上次观看于${_formatTime(item['time'])}'"),
    ])
    
    # 5. ranking_page.dart - fix isDark not defined in _RankingListState
    fix_file(os.path.join(BASE, 'pages', 'ranking_page.dart'), [
        ("placeholder: (_, __) => Container(color: isDark ? AppColors.darkElevated : AppColors.slate200),\n                      errorWidget: (_, __, ___) => Container(color: isDark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.movie)),",
         "placeholder: (_, __) => Container(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200),\n                      errorWidget: (_, __, ___) => Container(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkElevated : AppColors.slate200, child: const Icon(Icons.movie)),"),
    ])
    
    print("\nAll files fixed!")

if __name__ == '__main__':
    main()
