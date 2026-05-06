/// 文件名：app_theme.dart
/// 作者：杰哥（by：杰哥 / qq：2711793818）
/// 创建日期：2026-05-06
/// 作用：应用主题配置 - 天空蓝色系 + 蓝灰色系
/// 解释：统一管理所有颜色、阴影、圆角等主题参数，确保全APP视觉一致性。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 天空蓝色系色彩配置
class AppColors {
  AppColors._();

  // === 主色调 - 天空蓝 ===
  static const Color primary = Color(0xFF38BDF8);      // 明亮天空蓝
  static const Color primaryLight = Color(0xFF7DD3FC); // 浅天空蓝
  static const Color primaryDark = Color(0xFF0284C7);  // 深天空蓝
  static const Color primaryAccent = Color(0xFF0EA5E9); // 强调天空蓝

  // === 蓝灰色系 ===
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // === 深色模式背景 ===
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF151E2E);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkElevated = Color(0xFF27354F);

  // === 功能色 ===
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // === 文字色 ===
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textInverse = Colors.white;

  // === 玻璃拟态背景色 ===
  static const Color glassLight = Color(0x80FFFFFF);
  static const Color glassDark = Color(0x401E293B);
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color glassBorderDark = Color(0x3064748B);
}

/// 阴影配置
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get cardLight => [
    BoxShadow(
      color: const Color(0x1A0F172A),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardDark => [
    BoxShadow(
      color: const Color(0x40000000),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevatedLight => [
    BoxShadow(
      color: const Color(0x260F172A),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get elevatedDark => [
    BoxShadow(
      color: const Color(0x66000000),
      blurRadius: 20,
      offset: const Offset(0, 10),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get glowPrimary => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.4),
      blurRadius: 12,
      offset: Offset.zero,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get glowPrimarySmall => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 8,
      offset: Offset.zero,
      spreadRadius: 1,
    ),
  ];
}

/// 圆角配置
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;
}

/// 玻璃拟态装饰
class GlassDecoration {
  GlassDecoration._();

  static BoxDecoration light({double radius = 16}) => BoxDecoration(
    color: AppColors.glassLight,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.glassBorderLight,
      width: 1,
    ),
  );

  static BoxDecoration dark({double radius = 16}) => BoxDecoration(
    color: AppColors.glassDark,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.glassBorderDark,
      width: 1,
    ),
  );

  static BoxDecoration colored({
    required Color color,
    double radius = 16,
    double opacity = 0.15,
  }) => BoxDecoration(
    color: color.withOpacity(opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: color.withOpacity(0.3),
      width: 1,
    ),
  );
}

/// 渐变配置
class AppGradients {
  AppGradients._();

  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
  );

  static LinearGradient get primaryHorizontal => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.primaryAccent],
  );

  static LinearGradient get glassLight => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.6),
      Colors.white.withOpacity(0.2),
    ],
  );

  static LinearGradient get glassDark => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.darkCard.withOpacity(0.8),
      AppColors.darkSurface.withOpacity(0.6),
    ],
  );

  static LinearGradient get surfaceLight => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.slate50, AppColors.slate100],
  );

  static LinearGradient get surfaceDark => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.darkSurface, AppColors.darkBackground],
  );

  static LinearGradient get shimmer => LinearGradient(
    colors: [
      AppColors.slate200.withOpacity(0.5),
      AppColors.slate100.withOpacity(0.8),
      AppColors.slate200.withOpacity(0.5),
    ],
    stops: const [0.0, 0.5, 1.0],
  );
}

/// 主题构建器
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: isDark ? AppColors.darkSurface : AppColors.slate50,
      background: isDark ? AppColors.darkBackground : AppColors.slate50,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.slate50,
      cardColor: isDark ? AppColors.darkCard : Colors.white,
      dialogBackgroundColor: isDark ? AppColors.darkCard : Colors.white,
      dividerColor: isDark ? AppColors.slate700 : AppColors.slate200,

      // AppBar 主题
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.slate50,
        foregroundColor: isDark ? Colors.white : AppColors.slate900,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // 底部导航栏
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? AppColors.slate400 : AppColors.slate500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // TabBar 主题
      tabBarTheme: TabBarTheme(
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate500,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),

      // 卡片主题
      cardTheme: CardTheme(
        color: isDark ? AppColors.darkCard : Colors.white,
        elevation: isDark ? 4 : 2,
        shadowColor: isDark ? Colors.black.withOpacity(0.5) : AppColors.slate900.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : AppColors.slate100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // 底部Sheet主题
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // 对话框主题
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Chip主题
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.slate100,
        selectedColor: AppColors.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isDark ? AppColors.slate300 : AppColors.slate700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),

      // 滑块主题
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: isDark ? AppColors.slate700 : AppColors.slate200,
        thumbColor: Colors.white,
        overlayColor: AppColors.primary.withOpacity(0.2),
        trackHeight: 4,
      ),

      // 开关主题
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return Colors.white;
          }
          return isDark ? AppColors.slate400 : AppColors.slate300;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return isDark ? AppColors.slate700 : AppColors.slate200;
        }),
      ),

      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.slate200,
      ),
    );
  }
}

/// 玻璃拟态卡片 Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding,
    this.margin,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.glassDark : AppGradients.glassLight,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? AppColors.glassBorderDark
              : AppColors.glassBorderLight,
          width: 1,
        ),
        boxShadow: shadows ?? (isDark ? AppShadows.cardDark : AppShadows.cardLight),
      ),
      child: child,
    );
  }
}

/// 发光 Tab 指示器
class GlowTabIndicator extends Decoration {
  final Color color;
  final double radius;

  const GlowTabIndicator({
    this.color = AppColors.primary,
    this.radius = 3,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GlowTabPainter(color: color, radius: radius);
  }
}

class _GlowTabPainter extends BoxPainter {
  final Color color;
  final double radius;

  _GlowTabPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * 0.2,
        rect.bottom - radius * 2,
        rect.width * 0.6,
        radius * 2,
      ),
      Radius.circular(radius),
    );

    canvas.drawRRect(rrect, paint);

    // 绘制发光效果
    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawRRect(rrect, glowPaint);
  }
}

/// 渐变文字 Widget
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient = AppGradients.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(
        text,
        style: style?.copyWith(color: Colors.white) ??
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
