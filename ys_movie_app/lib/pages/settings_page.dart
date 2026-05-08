import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/api.dart';
import '../services/theme_provider.dart';
import '../theme/app_theme.dart';
import '../services/cache_service.dart';

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
    try {
      final size = await CacheService.getCacheSize();
      if (mounted) setState(() => _cacheSize = '${size.toStringAsFixed(2)}MB');
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '0.00MB');
    }
  }

  Future<void> _loadLoginState() async {
    try {
      final api = context.read<MacApi>();
      final ok = await api.checkLogin();
      if (mounted) setState(() => _isLoggedIn = ok);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    setState(() => _cacheSize = '娓呯悊涓?..');
    await CacheService.clearCache();
    if (mounted) {
      setState(() => _cacheSize = '0.00MB');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  void _showEditNicknameDialog() async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    if (!isLogin) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('璇峰厛鐧诲綍')));
       return;
    }
    final name = await api.getUserName();
    
    if (!mounted) return;
    final ctrl = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('淇敼鏄电О'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '新昵称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('鍙栨秷')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              
              final success = await api.modifyUserNickName(newName);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('鏄电О淇敼鎴愬姛')));
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('淇敼澶辫触')));
              }
            },
            child: const Text('淇濆瓨'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() async {
    final api = context.read<MacApi>();
    final isLogin = await api.checkLogin();
    if (!isLogin) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('璇峰厛鐧诲綍')));
       return;
    }

    if (!mounted) return;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('淇敼瀵嗙爜'),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('瀵嗙爜淇敼鎴愬姛锛岃閲嶆柊鐧诲綍')));
                await api.logout();
                widget.onLogout?.call();
                if (mounted) Navigator.pop(context); // Close settings page
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '淇敼澶辫触')));
              }
            },
            child: const Text('鎻愪氦'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final api = context.read<MacApi>();
    final hideVer = api.isHideVersion;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('鍏充簬鎴戜滑'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('鐙愮嫺褰辫', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (!hideVer) ...[
              const SizedBox(height: 8),
              Text('Version $_version', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ],
            const SizedBox(height: 16),
            const Text('我们致力于提供最优质的影视观看体验。\n如有侵权请联系我们删除。', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('纭畾')),
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
    // 濡傛灉娌℃湁URL浣嗘湁鏂囨湰锛屾垨鑰呮棤娉曟墦寮€URL锛屾樉绀烘枃鏈?
    if (contactText.isNotEmpty) {
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('鑱旂郴瀹㈡湇'),
           content: SelectableText(contactText),
           actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('纭畾'))],
         ),
       );
       return;
    }
    
    // Fallback
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('鏆傛棤瀹㈡湇鑱旂郴鏂瑰紡')));
  }

  String _getThemeName(String style) {
    switch (style) {
      case 'light': return '天空蓝';
      case 'dark': return '暗夜蓝';
      default: return '暗夜蓝';
    }
  }

  // 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  // 淇锛氫紭鍖栦富棰橀€夋嫨鐣岄潰锛屽鍔犲彲瑙嗗寲鎸囩ず锛堝嬀閫夋爣璁?楂樹寒鑳屾櫙+涓婚棰勮锛?
  void _showThemePicker() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = Theme.of(ctx).cardColor;
        final textColor = Theme.of(ctx).colorScheme.onSurface;
        final primary = Theme.of(ctx).colorScheme.primary;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 鏍囬
              Row(
                children: [
                  Text(
                    '閫夋嫨涓婚',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: textColor.withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '褰撳墠涓婚: ${_getThemeName(themeProvider.themeStyle)}',
                style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              
              // 澶╃┖钃濅富棰橀€夐」
              _buildThemeOption(
                context: ctx,
                title: '天空蓝',
                subtitle: '鏄庝寒娓呮柊',
                icon: Icons.wb_sunny,
                iconColor: AppColors.primary,
                bgColor: Theme.of(context).cardColor,
                textColor: Theme.of(context).colorScheme.onSurface,
                isSelected: themeProvider.themeStyle == 'light',
                onTap: () {
                  themeProvider.setThemeStyle('light');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              
              // 鏆楀钃濅富棰橀€夐」
              _buildThemeOption(
                context: ctx,
                title: '暗夜蓝',
                subtitle: '娣遍們鎶ょ溂',
                icon: Icons.nights_stay,
                iconColor: Theme.of(context).colorScheme.primary,
                bgColor: Theme.of(context).scaffoldBackgroundColor,
                textColor: Theme.of(context).colorScheme.onSurface,
                isSelected: themeProvider.themeStyle == 'dark',
                onTap: () {
                  themeProvider.setThemeStyle('dark');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // 寮€鍙戣€咃細鏉板摜缃戠粶绉戞妧 (qq: 2711793818)
  // 鏋勫缓涓婚閫夐」鍗＄墖
  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : AppColors.slate400.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 涓婚棰勮鍥炬爣
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate400.withOpacity(0.2)),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            // 涓婚淇℃伅
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // 閫変腑鐘舵€佹寚绀?
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.slate400.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.slate400.withOpacity(0.3)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // final isDark = themeProvider.isDark; // 涓嶅啀鍙渶瑕佽繖涓竷灏斿€?
    return Scaffold(
      appBar: AppBar(
        title: const Text('璁剧疆'),
        centerTitle: true,
      ),
      body: TexturedBackground(child: ListView(
        children: [
          const SizedBox(height: 10),
          _buildSectionHeader('甯歌'),
          ListTile(
            title: const Text('涓婚璁剧疆'),
            subtitle: Text(_getThemeName(themeProvider.themeStyle)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showThemePicker,
          ),
          ListTile(
            title: const Text('娓呯悊缂撳瓨'),
            subtitle: Text(_cacheSize),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _clearCache,
          ),
          
          _buildSectionHeader('璐﹀彿'),
          ListTile(
            title: const Text('淇敼鏄电О'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showEditNicknameDialog,
          ),
          ListTile(
            title: const Text('淇敼瀵嗙爜'),
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
              if (!mounted) return;
              if (update != null) {
                final vName = update['version_name']?.toString() ?? '';
                final desc = update['description']?.toString() ?? '';
                final isForce = update['is_force'] == true;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('发现新版本'),
                    content: Text('版本号：$vName\n\n$desc${isForce ? '\n\n此版本为强制更新' : ''}'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后再说')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // 通知 HomePage 弹出下载对话框
                        },
                        child: const Text('立即更新'),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
              }
            },
          ),
          ListTile(
            title: const Text('联系客服'),
            subtitle: context.read<MacApi>().contactText.isNotEmpty ? Text(context.read<MacApi>().contactText) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _contactService,
          ),
          ListTile(
            title: const Text('鍏充簬鎴戜滑'),
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
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.error,
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
