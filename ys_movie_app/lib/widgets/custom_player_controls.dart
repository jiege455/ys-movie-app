/// 文件名：custom_player_controls.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：自定义播放器控件，包含选集面板、清晰度选择、倍速控制等

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomPlayerControls extends BetterPlayerControls {
  final List<Map<String, dynamic>> episodes;
  final int currentEpisodeIndex;
  final ValueChanged<int> onEpisodeSelected;
  final Map<String, dynamic>? currentVod;

  const CustomPlayerControls({
    super.key,
    required this.episodes,
    required this.currentEpisodeIndex,
    required this.onEpisodeSelected,
    this.currentVod,
  });

  @override
  _CustomPlayerControlsState createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends BetterPlayerControlsState<CustomPlayerControls> {
  bool isAscending = true;

  List<Map<String, dynamic>> get _sortedEpisodes {
    final eps = List<Map<String, dynamic>>.from(widget.episodes);
    if (isAscending) {
      eps.sort((a, b) => (int.tryParse('${a['num'] ?? a['nid'] ?? 0}') ?? 0)
          .compareTo(int.tryParse('${b['num'] ?? b['nid'] ?? 0}') ?? 0));
    } else {
      eps.sort((a, b) => (int.tryParse('${b['num'] ?? b['nid'] ?? 0}') ?? 0)
          .compareTo(int.tryParse('${a['num'] ?? a['nid'] ?? 0}') ?? 0));
    }
    return eps;
  }

  void setStateSheet(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        super.build(context),
        Positioned(
          right: 12,
          top: 12,
          child: _buildEpisodeButton(),
        ),
      ],
    );
  }

  Widget _buildEpisodeButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEpisodeSheet(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.list, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${widget.currentEpisodeIndex + 1}/${widget.episodes.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodeSheet() {
    final eps = _sortedEpisodes;
    final total = eps.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xEE111827),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '选集 ($total)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            isAscending ? Icons.arrow_downward : Icons.arrow_upward,
                            color: AppColors.slate300,
                            size: 16,
                          ),
                          label: Text(
                            isAscending ? '正序' : '倒序',
                            style: const TextStyle(color: AppColors.slate300, fontSize: 13),
                          ),
                          onPressed: () {
                            setSheetState(() => isAscending = !isAscending);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: Colors.white.withOpacity(0.06),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: eps.length,
                      itemBuilder: (ctx, i) {
                        final ep = eps[i];
                        final epNum = ep['num'] ?? ep['nid'] ?? (i + 1);
                        final isSelected = i == widget.currentEpisodeIndex;
                        return GestureDetector(
                          onTap: () {
                            widget.onEpisodeSelected(i);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                            ),
                            child: Center(
                              child: Text(
                                '$epNum',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}