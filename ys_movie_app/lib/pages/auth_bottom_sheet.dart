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
  bool _regClosed = false;
  String _regTip = '';
  String _verifyCodeUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkRegStatus();
  }

  Future<void> _checkRegStatus() async {
    try {
      final api = context.read<MacApi>();
      final init = await api.getAppInit();
      final closed = !api.isRegOpen;
      if (mounted) {
        setState(() {
          _regClosed = closed;
          _regTip = '注册已关闭';
        });
      }
      if (!closed && api.isRegVerify) {
        _refreshVerifyCode();
      }
    } catch (_) {}
  }

  Future<void> _refreshVerifyCode() async {
    try {
      final api = context.read<MacApi>();
      final url = '${api.rootUrl}index.php/verify/index.html';
      setState(() {
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
      _showToast('请输入账号和密码');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final res = await api.login(username, password);
      if (res['success'] == true) {
        _showToast('登录成功');
        Navigator.pop(context);
        widget.onLoginSuccess?.call();
      } else {
        _showToast('登录失败: ${res['msg']}');
      }
    } catch (e) {
      _showToast('错误: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (_regClosed) {
      _showToast(_regTip.isNotEmpty ? _regTip : '注册已关闭');
      return;
    }

    final username = _regUserCtrl.text.trim();
    final password = _regPwdCtrl.text.trim();
    final confirm = _regPwd2Ctrl.text.trim();
    final verify = _regVerifyCtrl.text.trim();
    final inviteCode = _regInviteCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showToast('请输入账号和密码');
      return;
    }
    if (password != confirm) {
      _showToast('两次输入的密码不一致');
      return;
    }

    setState(() => _loading = true);
    try {
      final api = context.read<MacApi>();
      final res = await api.register(username, password, verifyCode: verify, inviteCode: inviteCode);
      if (res['success'] == true) {
        _showToast('注册成功，正在自动登录...');
        await api.login(username, password);
        if (mounted) {
          Navigator.pop(context);
          widget.onLoginSuccess?.call();
        }
      } else {
        _showToast('注册失败: ${res['msg']}');
        if (api.isRegVerify) _refreshVerifyCode();
      }
    } catch (e) {
      _showToast('错误: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部品牌区域
            _buildHeader(isDark, primary, onSurface),
            // Tab 切换
            _buildTabBar(isDark, primary),
            // 表单内容
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginForm(primary, onSurface, isDark),
                  _buildRegisterForm(primary, onSurface, isDark),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color primary, Color onSurface) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [primary.withOpacity(0.15), Colors.transparent]
              : [primary.withOpacity(0.08), Colors.transparent],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.slate600.withOpacity(0.6)
                    : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 品牌图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withOpacity(0.7)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.movie_filter,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '欢迎来到狐狸影视',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: onSurface,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '登录即可同步观影记录与收藏',
            style: TextStyle(
              fontSize: 13,
              color: onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkElevated.withOpacity(0.5)
            : AppColors.slate100.withOpacity(0.6),
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
          gradient: LinearGradient(
            colors: [primary, primary.withOpacity(0.8)],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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

  Widget _buildLoginForm(Color primary, Color onSurface, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          _buildInputField(
            controller: _loginUserCtrl,
            icon: Icons.person_outline,
            hint: '请输入用户名/手机号',
            primary: primary,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _loginPwdCtrl,
            icon: Icons.lock_outline,
            hint: '请输入密码',
            primary: primary,
            isDark: isDark,
            isPassword: true,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 28),
          _buildSubmitButton(
            text: '立即登录',
            primary: primary,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '登录即代表同意',
                style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 12),
              ),
              GestureDetector(
                onTap: () => _showAgreement('用户协议', 'agreement_content'),
                child: Text(
                  '《用户协议》',
                  style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '和',
                style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 12),
              ),
              GestureDetector(
                onTap: () => _showAgreement('隐私政策', 'privacy_content'),
                child: Text(
                  '《隐私政策》',
                  style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(Color primary, Color onSurface, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          _buildInputField(
            controller: _regUserCtrl,
            icon: Icons.person_add_alt,
            hint: '请输入注册账号',
            primary: primary,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _regPwdCtrl,
            icon: Icons.lock_outline,
            hint: '设置登录密码',
            primary: primary,
            isDark: isDark,
            isPassword: true,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _regPwd2Ctrl,
            icon: Icons.check_circle_outline,
            hint: '再次输入密码',
            primary: primary,
            isDark: isDark,
            isPassword: true,
          ),
          if (_verifyCodeUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _regVerifyCtrl,
                    icon: Icons.verified_outlined,
                    hint: '验证码',
                    primary: primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _refreshVerifyCode,
                  child: Container(
                    width: 110,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withOpacity(0.3), width: 1),
                      color: isDark ? AppColors.darkElevated : AppColors.slate50,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _verifyCodeUrl.isNotEmpty
                        ? Image.network(_verifyCodeUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.refresh, color: primary, size: 20)))
                        : Center(child: Icon(Icons.refresh, color: primary, size: 20)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _buildInputField(
            controller: _regInviteCtrl,
            icon: Icons.card_giftcard_outlined,
            hint: '邀请码（选填）',
            primary: primary,
            isDark: isDark,
          ),
          if (_regClosed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.error.withOpacity(0.7), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _regTip.isNotEmpty ? _regTip : '注册已关闭',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          _buildSubmitButton(
            text: _regClosed ? '注册已关闭' : '立即注册',
            primary: primary,
            onPressed: _regClosed ? () {} : _handleRegister,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
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
        color: isDark
            ? AppColors.darkElevated.withOpacity(0.6)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.slate700.withOpacity(0.4)
              : AppColors.slate200.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: isDark ? AppColors.slate100 : AppColors.slate800,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 4, right: 10),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? AppColors.slate500 : AppColors.slate400,
            fontSize: 14,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String text,
    required Color primary,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return AppColors.slate400;
            }
            return Colors.transparent;
          }),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _loading
                  ? [AppColors.slate400, AppColors.slate500]
                  : [primary, primary.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    text,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAgreement(String title, String contentKey) async {
    String content = "正在加载...";
    try {
      final api = context.read<MacApi>();
      final init = await api.getAppInit();
      if (init['app_page_setting'] is Map) {
        final setting = init['app_page_setting'];
        final inner = (setting['app_page_setting'] is Map) ? setting['app_page_setting'] : setting;
        content = inner[contentKey]?.toString() ?? "暂无$title内容，请联系客服。";
      }
    } catch (_) {
      content = "获取失败，请检查网络。";
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}