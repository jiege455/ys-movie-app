import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';

/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 登录页面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    final pwd = _pwdCtrl.text.trim();
    if (name.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final res = await api.login(name, pwd);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录成功')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['msg'] ?? '登录失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        centerTitle: true,
      ),
      body: TexturedBackground(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_circle,
                  size: 48,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '欢迎回来',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请登录您的账号以继续',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '用户名',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.person_outline, color: scheme.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _pwdCtrl,
                obscureText: _obscure,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '密码',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2),
                      )
                    : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
    );
  }
}
