/// 文件名：keep_alive_wrapper.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2025-12-16
/// 作用：保持 TabBarView 中每个 Tab 的状态不被销毁
/// 解释：切换分类时，已经加载的内容不会重新加载，提升体验。
/// 开发者：杰哥网络科技 (qq: 2711793818)

import 'package:flutter/material.dart';

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
