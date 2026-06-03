import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CommentItem extends StatelessWidget {
  final String avatarUrl;
  final String userName;
  final String time;
  final String content;
  final bool isPinned;
  final bool isAd;
  final Map<String, dynamic>? adData;

  const CommentItem({
    super.key,
    required this.avatarUrl,
    required this.userName,
    required this.time,
    required this.content,
    this.isPinned = false,
    this.isAd = false,
    this.adData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? AppColors.slate900;
    final subTextColor = theme.textTheme.bodySmall?.color ?? AppColors.slate400;
    final cardColor = theme.cardColor;

    // 广告样式
    if (isAd) {
      return GestureDetector(
        onTap: () async {
          final link = content;
          if (link.isNotEmpty) {
            final uri = Uri.tryParse(link);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: CachedNetworkImageProvider(avatarUrl),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.topRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.slate600,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: const Text('广告',
                style: TextStyle(color: AppColors.primaryLight, fontSize: 10)),
          ),
        ),
      );
    }

    // 置顶评论样式 (与普通评论保持一致，但增加标识)
    if (isPinned) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: isDark ? AppColors.slate700.withOpacity(0.1) : AppColors.slate200, width: 0.5)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头像
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark ? AppColors.slate700.withOpacity(0.1) : AppColors.slate200,
                    backgroundImage: (avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: (avatarUrl.isNotEmpty) ? null : const Icon(Icons.person, color: AppColors.slate400, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // 内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 名字 + 标识
                        Padding(
                          padding: const EdgeInsets.only(right: 40), // 留出置顶标签的位置
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    color: AppColors.warning, // 橙色名字保留
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          content,
                          style: TextStyle(
                            color: textColor, // 使用普通文本颜色
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 右侧置顶标签 (使用 Positioned 绝对定位到右上角)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.error.withOpacity(0.5), width: 0.5),
                ),
                child: const Text(
                  '置顶',
                  style: TextStyle(fontSize: 10, color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 普通评论样式
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppColors.slate700.withOpacity(0.1) : AppColors.slate200, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark ? AppColors.slate700.withOpacity(0.1) : AppColors.slate200,
            backgroundImage:
                (avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
            child: (avatarUrl.isNotEmpty)
                ? null
                : const Icon(Icons.person, color: AppColors.slate400, size: 24),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名字 + 时间
                Row(
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: TextStyle(fontSize: 11, color: subTextColor.withOpacity(0.7)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 评论内容
                Text(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
