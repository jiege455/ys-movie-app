/// 文件名：slide_banner.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：轮播横幅组件，展示首页顶部滑动Banner

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SlideBanner extends StatefulWidget {
  final List<String> images;
  final ValueChanged<int>? onTap;
  final BoxFit fit;

  const SlideBanner({super.key, required this.images, this.onTap, this.fit = BoxFit.cover});

  @override
  State<SlideBanner> createState() => _SlideBannerState();
}

class _SlideBannerState extends State<SlideBanner> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          items: widget.images.map((url) {
            return GestureDetector(
              onTap: () {
                final idx = widget.images.indexOf(url);
                widget.onTap?.call(idx);
              },
              child: CachedNetworkImage(
                imageUrl: url,
                fit: widget.fit,
                width: double.infinity,
                placeholder: (_, __) => Container(color: AppColors.darkElevated),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.darkElevated, child: const Icon(Icons.broken_image, color: AppColors.slate500)),
              ),
            );
          }).toList(),
          options: CarouselOptions(
            autoPlay: widget.images.length > 1,
            enlargeCenterPage: false,
            viewportFraction: 1.0,
            onPageChanged: (index, _) {
              setState(() => _current = index);
            },
          ),
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.images.asMap().entries.map((entry) {
                return Container(
                  width: _current == entry.key ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _current == entry.key
                        ? AppColors.primaryLight
                        : AppColors.slate500,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
