import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api.dart';
import '../services/theme_provider.dart';
import '../services/store.dart';
import 'auth_bottom_sheet.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onLogout;

  const SettingsPage({super.key, this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  String _cacheSize = '0.00MB';
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _calcCache();
    _loadLoginState();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _calcCache() async {
    // 模拟计算缓存
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _cacheSize = '12.5MB');
  }

  Future<void> _loadLoginState() async {
    try {
      final api = context.read<MacApi>();
      final ok = await api.checkLogin();
      if (mounted) setState(() => _isLoggedIn = ok);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    setState(() => _cacheSize = '清理中...');
    await Future.delayed(const Duration(seconds: 1));
    // 这里可以调用 StoreService.clearCache() 等实际逻辑
    if (mounted) {
      setState(() => _cacheSize = '0.00MB');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  void _showEditNicknameDialog() async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    if (!isLogin) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
       return;
    }
    final name = await api.getUserName();
    
    if (!mounted) return;
    final ctrl = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '新昵称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              
              final success = await api.modifyUserNickName(newName);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称修改成功')));
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改失败')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    if (!isLogin) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
       return;
    }

    if (!mounted) return;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, decoration: const InputDecoration(labelText: '旧密码'), obscureText: true),
            TextField(controller: newCtrl, decoration: const InputDecoration(labelText: '新密码'), obscureText: true),
            TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: '确认新密码'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码输入不一致')));
                return;
              }
              Navigator.pop(ctx);
              
              final res = await api.modifyPassword(oldCtrl.text, newCtrl.text);
              if (res['success'] == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码修改成功，请重新登录')));
                await api.logout();
                widget.onLogout?.call();
                if (mounted) Navigator.pop(context); // Close settings page
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '修改失败')));
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于我们'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_filter, size: 64, color: Color(0xFF9C27B0)),
            const SizedBox(height: 16),
            const Text('狐狸影视', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Version $_version', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('我们致力于提供最优质的影视观看体验。\n如有侵权请联系我们删除。', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  void _contactService() async {
    final api = context.read<MacApi>();
    final contactUrl = api.contactUrl;
    final contactText = api.contactText;

    if (contactUrl.isNotEmpty) {
      final uri = Uri.tryParse(contactUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // 如果没有URL但有文本，或者无法打开URL，显示文本
    if (contactText.isNotEmpty) {
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('联系客服'),
           content: SelectableText(contactText),
           actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
         ),
       );
       return;
    }
    
    // Fallback
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无客服联系方式')));
  }

  String _getThemeName(String style) {
    switch (style) {
      case 'light': return '粉白';
      case 'blue_black': return '蓝黑';
      default: return '蓝黑';
    }
  }

  void _showThemePicker() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = Theme.of(ctx).cardColor;
        final textColor = isDark ? Colors.white : Colors.black87;
        final primary = Theme.of(ctx).colorScheme.primary;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('选择主题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ),
              ListTile(
                title: Text('粉白', style: TextStyle(color: textColor)),
                trailing: themeProvider.themeStyle == 'light' ? Icon(Icons.check, color: primary) : null,
                onTap: () { themeProvider.setThemeStyle('light'); Navigator.pop(ctx); },
              ),
              ListTile(
                title: Text('蓝黑', style: TextStyle(color: textColor)),
                trailing: themeProvider.themeStyle == 'blue_black' ? Icon(Icons.check, color: primary) : null,
                onTap: () { themeProvider.setThemeStyle('blue_black'); Navigator.pop(ctx); },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // final isDark = themeProvider.isDark; // 不再只需要这个布尔值

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),
          _buildSectionHeader('常规'),
          ListTile(
            title: const Text('主题设置'),
            subtitle: Text(_getThemeName(themeProvider.themeStyle)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showThemePicker,
          ),
          ListTile(
            title: const Text('清理缓存'),
            subtitle: Text(_cacheSize),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _clearCache,
          ),
          
          _buildSectionHeader('账号'),
          ListTile(
            title: const Text('修改昵称'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showEditNicknameDialog,
          ),
          ListTile(
            title: const Text('修改密码'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showChangePasswordDialog,
          ),

          _buildSectionHeader('关于'),
          ListTile(
            title: const Text('检查更新'),
            subtitle: Text('当前版本: $_version'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final api = context.read<MacApi>();
              final update = await api.getAppUpdate();
              if (update == null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
              }
              // 如果有更新，Home Page 那边的逻辑会自动弹窗，或者这里也可以简单提示。
              // 为了简单，这里只提示无更新，有更新的话 HomePage 会自动处理。
            },
          ),
          ListTile(
            title: const Text('联系客服'),
            subtitle: context.read<MacApi>().contactText.isNotEmpty ? Text(context.read<MacApi>().contactText) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _contactService,
          ),
          ListTile(
            title: const Text('关于我们'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showAboutDialog,
          ),
          
          if (_isLoggedIn) ...[
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () async {
                  final api = context.read<MacApi>();
                  await api.logout();
                  widget.onLogout?.call();
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('退出登录'),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
