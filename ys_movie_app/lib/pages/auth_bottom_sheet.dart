import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';

/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：半屏弹窗式的登录/注册页面
void showAuthBottomSheet(BuildContext context, {VoidCallback? onLoginSuccess}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.65,
    ),
    builder: (context) => AuthBottomSheet(onLoginSuccess: onLoginSuccess),
  );
}

class AuthBottomSheet extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthBottomSheet({super.key, this.onLoginSuccess});

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginUserCtrl = TextEditingController();
  final _loginPwdCtrl = TextEditingController();
  final _regUserCtrl = TextEditingController();
  final _regPwdCtrl = TextEditingController();
  final _regPwd2Ctrl = TextEditingController();
  final _regVerifyCtrl = TextEditingController();
  final _regInviteCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureText = true;
  bool _needVerify = false;
  String _verifyCodeUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    try {
      final api = context.read<MacApi>();
      await api.getAppInit();
      if (api.isRegVerify) {
        _refreshVerifyCode();
      }
    } catch (_) {}
  }

  Future<void> _refreshVerifyCode() async {
    try {
      final api = context.read<MacApi>();
      final url = '${api.rootUrl}index.php/verify/index.html';
      setState(() {
        _needVerify = true;
        _verifyCodeUrl = '$url?r=${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUserCtrl.dispose();
    _loginPwdCtrl.dispose();
    _regUserCtrl.dispose();
    _regPwdCtrl.dispose();
    _regPwd2Ctrl.dispose();
    _regVerifyCtrl.dispose();
    _regInviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _loginUserCtrl.text.trim();
    final password = _loginPwdCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('请输入账号和密码');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final res = await api.login(username, password);
      if (res['success'] == true) {
        _showSuccess('登录成功');
        if (mounted) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
        }
      } else {
        _showError(res['msg']?.toString() ?? '登录失败，请检查账号密码');
      }
    } catch (e) {
      _showError('网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    final username = _regUserCtrl.text.trim();
    final password = _regPwdCtrl.text.trim();
    final confirm = _regPwd2Ctrl.text.trim();
    final verify = _regVerifyCtrl.text.trim();
    final inviteCode = _regInviteCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('请输入账号和密码');
      return;
    }
    if (username.length < 3) {
      _showError('账号至少3个字符');
      return;
    }
    if (password.length < 6) {
      _showError('密码至少6位');
      return;
    }
    if (password != confirm) {
      _showError('两次输入的密码不一致');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final res = await api.register(username, password, verifyCode: verify, inviteCode: inviteCode);
      if (res['success'] == true) {
        _showSuccess('注册成功，正在自动登录...');
        // 注册成功后自动登录
        final loginRes = await api.login(username, password);
        if (loginRes['success'] == true) {
          _showSuccess('登录成功');
        }
        if (mounted) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
        }
      } else {
        _showError(res['msg']?.toString() ?? '注册失败，请稍后重试');
        if (_needVerify) _refreshVerifyCode();
      }
    } catch (e) {
      _showError('网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;
    final bgColor = isDark ? AppColors.darkCard : Colors.white;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark, primary),
            _buildTabBar(isDark, primary),
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(primary, isDark),
                  _buildRegisterForm(primary, isDark),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [primary.withOpacity(0.12), Colors.transparent]
              : [primary.withOpacity(0.06), Colors.transparent],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate600.withOpacity(0.5) : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '欢迎来到狐狸影视',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? AppColors.slate100 : AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(
            '登录即可同步观影记录与收藏',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.slate400 : AppColors.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated.withOpacity(0.4) : AppColors.slate100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate500,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [primary, primary.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicatorPadding: const EdgeInsets.all(3),
        splashFactory: NoSplash.splashFactory,
        tabs: const [
          Tab(height: 44, child: Text('登录')),
          Tab(height: 44, child: Text('注册')),
        ],
      ),
    );
  }

  Widget _buildLoginForm(Color primary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          _buildTextField(
            controller: _loginUserCtrl,
            icon: Icons.person_outline,
            hint: '请输入用户名/手机号',
            primary: primary, isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _loginPwdCtrl,
            icon: Icons.lock_outline,
            hint: '请输入密码',
            primary: primary, isDark: isDark,
            isPassword: true,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 28),
          _buildButton(text: '立即登录', primary: primary, onTap: _handleLogin),
          const SizedBox(height: 16),
          Text('登录即代表同意《用户协议》和《隐私政策》', style: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(Color primary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          _buildTextField(
            controller: _regUserCtrl,
            icon: Icons.person_add_alt_outlined,
            hint: '请输入注册账号',
            primary: primary, isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _regPwdCtrl,
            icon: Icons.lock_outline,
            hint: '设置登录密码(至少6位)',
            primary: primary, isDark: isDark,
            isPassword: true,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _regPwd2Ctrl,
            icon: Icons.check_circle_outline,
            hint: '再次输入密码',
            primary: primary, isDark: isDark,
            isPassword: true,
          ),
          if (_needVerify) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _buildTextField(controller: _regVerifyCtrl, icon: Icons.verified_outlined, hint: '验证码', primary: primary, isDark: isDark)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _refreshVerifyCode,
                child: Container(
                  width: 100, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primary.withOpacity(0.25)),
                    color: isDark ? AppColors.darkElevated : AppColors.slate50,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _verifyCodeUrl.isNotEmpty
                      ? Image.network(_verifyCodeUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.refresh, color: primary, size: 20)))
                      : Center(child: Icon(Icons.refresh, color: primary, size: 20)),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          _buildTextField(
            controller: _regInviteCtrl,
            icon: Icons.card_giftcard_outlined,
            hint: '邀请码（选填）',
            primary: primary, isDark: isDark,
          ),
          const SizedBox(height: 28),
          _buildButton(text: '立即注册', primary: primary, onTap: _handleRegister),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required Color primary,
    required bool isDark,
    bool isPassword = false,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated.withOpacity(0.5) : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.slate700.withOpacity(0.35) : AppColors.slate200.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.06 : 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        onSubmitted: onSubmitted,
        style: TextStyle(color: isDark ? AppColors.slate100 : AppColors.slate800, fontSize: 15),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4, right: 10),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: primary, size: 20),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400, fontSize: 14),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: isDark ? AppColors.slate500 : AppColors.slate400, size: 20),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildButton({required String text, required Color primary, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _loading
                ? const LinearGradient(colors: [AppColors.slate400, AppColors.slate500])
                : const LinearGradient(colors: [AppColors.primary, AppColors.primaryAccent]),
            boxShadow: [BoxShadow(color: primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}