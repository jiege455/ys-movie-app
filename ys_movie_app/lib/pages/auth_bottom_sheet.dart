import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';

/// 开发者：杰哥
/// 作用：半屏弹窗式的登录/注册页面
/// 解释：点击登录后从底部弹出来的那个漂亮的框框。
void showAuthBottomSheet(BuildContext context, {VoidCallback? onLoginSuccess}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // 允许全屏高度
    backgroundColor: Colors.transparent,
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
  bool _regClosed = false; // 注册是否关闭
  String _regTip = ''; // 注册关闭提示
  String _verifyCodeUrl = ''; // 验证码图片URL
  String _verifyCodeSession = ''; // 验证码session

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkRegStatus();
  }

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 修复：检查注册开关状态
  Future<void> _checkRegStatus() async {
    try {
      final api = context.read<MacApi>();
      final init = await api.getAppInit();
      final config = api.appConfig;
      final closed = (int.tryParse('${config['system_reg_status'] ?? 1}') ?? 1) == 0;
      if (mounted) {
        setState(() {
          _regClosed = closed;
          _regTip = config['system_reg_tip']?.toString() ?? '注册已关闭';
        });
      }
      // 如果需要验证码，加载验证码
      if (!closed && api.isRegVerify) {
        _refreshVerifyCode();
      }
    } catch (_) {}
  }

  // 开发者：杰哥网络科技 (qq: 2711793818)
  // 修复：刷新验证码
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
    // 开发者：杰哥网络科技 (qq: 2711793818)
    // 修复：注册前检查开关状态
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
      // 修复：传入邀请码
      final res = await api.register(username, password, verifyCode: verify, inviteCode: inviteCode);
      if (res['success'] == true) {
        _showToast('注册成功，正在自动登录...');
        // 自动登录
        await api.login(username, password);
        if (mounted) {
           Navigator.pop(context);
           widget.onLoginSuccess?.call();
        }
      } else {
        _showToast('注册失败: ${res['msg']}');
        // 刷新验证码
        if (api.isRegVerify) _refreshVerifyCode();
      }
    } catch (e) {
      _showToast('错误: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    // 键盘弹出时，底部 padding 需要增加
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部拖拽条
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          
          // Tab 切换
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '登录'),
              Tab(text: '注册'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 内容区域
          SizedBox(
            height: 300, // 给个固定高度或者自适应
            child: TabBarView(
              controller: _tabController,
              children: [
                // 登录表单
                _buildLoginForm(),
                // 注册表单
                _buildRegisterForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAgreement(String title, String contentKey) async {
    // 实际项目中应从 API 获取协议内容，这里暂时使用模拟数据或简单的文本
    // 如果后台有配置协议链接，可以打开 WebView
    // 这里简单弹窗显示文本
    
    String content = "正在加载...";
    // 尝试获取配置
    try {
      final api = context.read<MacApi>();
      final init = await api.getAppInit();
      // 假设后台在 app_page_setting 里有 agreement 和 privacy 字段
      // 如果没有，使用默认文案
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
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTextField(
            controller: _loginUserCtrl,
            label: '账号',
            icon: Icons.person_outline,
            hint: '请输入用户名/手机号',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginPwdCtrl,
            label: '密码',
            icon: Icons.lock_outline,
            hint: '请输入密码',
            isPassword: true,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 30),
          _buildButton(
            text: '立即登录',
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('登录即代表同意', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              GestureDetector(
                onTap: () => _showAgreement('用户协议', 'agreement_content'),
                child: Text('《用户协议》', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
              ),
              Text('和', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              GestureDetector(
                onTap: () => _showAgreement('隐私政策', 'privacy_content'),
                child: Text('《隐私政策》', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTextField(
            controller: _regUserCtrl,
            label: '账号',
            icon: Icons.person_add_alt,
            hint: '请输入注册账号',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _regPwdCtrl,
            label: '密码',
            icon: Icons.lock_outline,
            hint: '设置登录密码',
            isPassword: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _regPwd2Ctrl,
            label: '确认密码',
            icon: Icons.check_circle_outline,
            hint: '再次输入密码',
            isPassword: true,
          ),
          // 开发者：杰哥网络科技 (qq: 2711793818)
          // 修复：注册表单增加验证码和邀请码
          if (_verifyCodeUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _regVerifyCtrl,
                    label: '验证码',
                    icon: Icons.verified_outlined,
                    hint: '请输入验证码',
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _refreshVerifyCode,
                  child: Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _verifyCodeUrl.isNotEmpty
                      ? Image.network(_verifyCodeUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('点击刷新')))
                      : const Center(child: Text('点击刷新')),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildTextField(
            controller: _regInviteCtrl,
            label: '邀请码',
            icon: Icons.card_giftcard_outlined,
            hint: '没有可不填',
          ),
          if (_regClosed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[400], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _regTip.isNotEmpty ? _regTip : '注册已关闭',
                      style: TextStyle(color: Colors.red[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
          _buildButton(
            text: _regClosed ? '注册已关闭' : '立即注册',
            onPressed: _regClosed ? () {} : _handleRegister,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isPassword = false,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          icon: Icon(icon, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          border: InputBorder.none,
          labelText: label,
          hintText: hint,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
