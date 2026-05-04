import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';

/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：求片找片页面，对接后台 jgappapi.index/find 接口
/// 解释：用户提交想看的影片，后台管理员看到后会帮忙找片。
class FindPage extends StatefulWidget {
  const FindPage({Key? key}) : super(key: key);

  @override
  State<FindPage> createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final remark = _remarkCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入片名')));
      return;
    }

    final api = context.read<MacApi>();

    setState(() => _submitting = true);
    try {
      final ok = await api.sendFind(name: name, remark: remark);
      if (!mounted) return;
      if (ok) {
        _nameCtrl.clear();
        _remarkCtrl.clear();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('求片已提交，耐心等待处理')));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提交失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('求片找片'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.movie_filter, color: scheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '想看的片子找不到？告诉我片名，站长帮你找！\n提交后请留意消息中心的“求片回复”。',
                      style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('影片名称（必填）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: '准确的片名更容易找到哦',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search, color: scheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('备注说明（选填）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _remarkCtrl,
                maxLines: null,
                expands: true,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: '例如：希望能有4K画质、国语配音、或者具体哪一季...',
                  hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 4,
                ),
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('提交求片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
