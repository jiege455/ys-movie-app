import os
import re

BASE = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib'

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_home_page():
    path = os.path.join(BASE, 'pages', 'home_page.dart')
    content = read_file(path)
    
    # 1. Add TexturedBackground to build method - wrap the SafeArea
    # Currently: Scaffold(backgroundColor: ..., body: SafeArea(child: NestedScrollView(...)))
    # Change to: Scaffold(backgroundColor: ..., body: TexturedBackground(child: SafeArea(child: NestedScrollView(...))))
    
    # Replace the build method to add TexturedBackground
    old = """    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.slate50,
      body: SafeArea(
        child: NestedScrollView("""
    
    new = """    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.slate50,
      body: TexturedBackground(
        child: SafeArea(
        child: NestedScrollView("""
    
    content = content.replace(old, new)
    
    # Fix the closing - need to add extra closing paren for TexturedBackground
    # Find the end of build method - look for the closing of Scaffold
    old2 = """        ),
      ),
    );
  }

  // ── 搜索栏 ──"""
    
    new2 = """        ),
        ),
      ),
    );
  }

  // ── 搜索栏 ──"""
    
    content = content.replace(old2, new2)
    
    # 2. Replace Colors.white used as background with AppColors.slate50 or theme equivalent
    # In shimmer: color: Colors.white -> color: AppColors.slate50
    content = content.replace(
        "color: Colors.white,\n            borderRadius: BorderRadius.circular(20),",
        "color: AppColors.slate50,\n            borderRadius: BorderRadius.circular(20),"
    )
    content = content.replace(
        "color: Colors.white,\n            borderRadius: BorderRadius.circular(8),",
        "color: AppColors.slate50,\n            borderRadius: BorderRadius.circular(8),"
    )
    
    # 3. Replace Colors.white used in card backgrounds
    content = content.replace(
        "color: isDark ? AppColors.darkCard : Colors.white,",
        "color: isDark ? AppColors.darkCard : AppColors.slate50,"
    )
    
    write_file(path, content)
    print(f"Fixed: {path}")

def fix_ranking_page():
    path = os.path.join(BASE, 'pages', 'ranking_page.dart')
    content = read_file(path)
    
    # 1. Replace _DecorativeBackground with TexturedBackground
    # The ranking page uses Stack with _DecorativeBackground + content
    # Change to use TexturedBackground like profile page
    
    old = """      body: Stack(
        children: [
          // 装饰图案层
          Positioned.fill(
            child: _DecorativeBackground(
              isDark: isDark,
              primaryColor: primaryColor,
            ),
          ),
          // 内容层
          SafeArea("""
    
    new = """      body: TexturedBackground(
        child: SafeArea("""
    
    content = content.replace(old, new)
    
    # Fix the closing brackets - remove one level of Stack
    # The old structure: Stack(children: [PositionedFill, SafeArea(Column(...))])
    # The new structure: TexturedBackground(child: SafeArea(Column(...)))
    # Need to find the closing of SafeArea and remove the extra ], from Stack
    
    # Find: ),\n          ),\n        ],\n      ),\n    ); which is the end of Stack
    old2 = """            ],
          ),
          ),
        ],
      ),
    );
  }
}"""
    
    new2 = """            ],
          ),
          ),
      ),
    );
  }
}"""
    
    content = content.replace(old2, new2)
    
    # 2. Replace Colors.white.withOpacity(0.1) with AppColors.slate700.withOpacity(0.1) for dark borders
    content = content.replace(
        "Colors.white.withOpacity(0.1)",
        "AppColors.slate700.withOpacity(0.1)"
    )
    
    # 3. Replace Colors.white in decorative background gradient with AppColors.slate50
    content = content.replace(
        """              : [
                  Colors.white,
                  primaryColor.withAlpha(25),
                  Colors.white,
                ],""",
        """              : [
                  AppColors.slate50,
                  primaryColor.withAlpha(25),
                  AppColors.slate50,
                ],"""
    )
    
    # 4. Fix developer comment format
    content = content.replace(
        """// by：杰哥 
// qq： 2711793818

/// 开发者：杰哥 (qq: 2711793818)""",
        """/// 开发者：杰哥网络科技 (qq: 2711793818)"""
    )
    
    # 5. Remove the _DecorativeBackground and _DecorativePainter classes since they're no longer used
    # Find and remove from "/// 装饰背景组件" to end of _DecorativePainter class
    pattern = r"\n/// 装饰背景组件.*?bool shouldRepaint\(covariant _DecorativePainter oldDelegate\) => oldDelegate\.primaryColor != primaryColor \|\| oldDelegate\.isDark != isDark;\n  \}\n\}"
    
    match = re.search(pattern, content, re.DOTALL)
    if match:
        content = content[:match.start()] + "\n}" + content[match.end():]
        print("  Removed _DecorativeBackground and _DecorativePainter classes")
    
    write_file(path, content)
    print(f"Fixed: {path}")

def fix_profile_page():
    path = os.path.join(BASE, 'pages', 'profile_page.dart')
    content = read_file(path)
    
    # 1. Fix developer comment format
    content = content.replace(
        """// by：杰哥 
// qq： 2711793818
// 修复历史记录刷新问题""",
        """/// 开发者：杰哥网络科技 (qq: 2711793818)"""
    )
    
    content = content.replace(
        """/**\n * 开发者：杰哥\n * 作用：我的页面""",
        """/// 开发者：杰哥网络科技 (qq: 2711793818)
/// 作用：我的页面"""
    )
    
    # 2. Replace Colors.white used as gradient end in light mode
    content = content.replace(
        ": [primaryColor.withAlpha(35), Colors.white],",
        ": [primaryColor.withAlpha(35), AppColors.slate50],"
    )
    
    # 3. Replace Colors.white used as avatar border
    content = content.replace(
        "border: Border.all(color: Colors.white, width: 2),",
        "border: Border.all(color: AppColors.primaryLight, width: 2),"
    )
    
    # 4. Replace Colors.black.withAlpha for shadow
    content = content.replace(
        "Colors.black.withAlpha((255 * 0.1).round())",
        "AppColors.slate900.withAlpha((255 * 0.1).round())"
    )
    
    # 5. Remove the commented-out hardcoded color
    content = content.replace(
        "      // backgroundColor: const Color(0xFFF5F5F5), // Removed hardcoded color\n",
        ""
    )
    
    write_file(path, content)
    print(f"Fixed: {path}")

def fix_other_pages():
    fixes = {
        'feedback_center_page.dart': [
            ("Colors.white, strokeWidth: 2))", "AppColors.primary, strokeWidth: 2))"),
            ("Colors.red", "AppColors.error"),
        ],
        'find_page.dart': [
            ("foregroundColor: Colors.white,", "foregroundColor: AppColors.primaryLight,"),
            ("CircularProgressIndicator(color: Colors.white", "CircularProgressIndicator(color: AppColors.primaryLight"),
        ],
        'week_page.dart': [
            ("labelColor: Colors.white,", "labelColor: AppColors.primaryLight,"),
            ("Colors.transparent, Colors.black87", "Colors.transparent, AppColors.slate900"),
            ("TextStyle(color: Colors.white, fontSize: 10)", "TextStyle(color: AppColors.primaryLight, fontSize: 10)"),
        ],
        'auth_bottom_sheet.dart': [
            ("Colors.red[50]", "AppColors.error.withOpacity(0.05)"),
            ("Colors.red[200]!", "AppColors.error.withOpacity(0.3)"),
            ("Colors.red[400]", "AppColors.error.withOpacity(0.7)"),
            ("Colors.red[600]", "AppColors.error"),
            ("foregroundColor: Colors.white,", "foregroundColor: AppColors.primaryLight,"),
            ("CircularProgressIndicator(color: Colors.white", "CircularProgressIndicator(color: AppColors.primaryLight"),
        ],
        'detail_page.dart': [
            ("color: Colors.white, size: 42)", "color: AppColors.primaryLight, size: 42)"),
            ("TextStyle(color: Colors.white)", "TextStyle(color: AppColors.primaryLight)"),
            ("backgroundColor: Colors.white24", "backgroundColor: AppColors.primary.withOpacity(0.24)"),
            ("TextStyle(color: Colors.white,", "TextStyle(color: AppColors.primaryLight,"),
            ("color: Colors.blue)", "color: AppColors.primary)"),
            ("color: Colors.black,", "color: AppColors.darkBackground,"),
            ("Colors.black87", "AppColors.slate900"),
            ("Colors.black54", "AppColors.slate600"),
            ("Colors.black12", "AppColors.slate200"),
            ("Colors.black.withOpacity(0.05)", "AppColors.slate900.withOpacity(0.05)"),
            ("Colors.black.withOpacity(0.3)", "AppColors.slate900.withOpacity(0.3)"),
            ("Colors.red", "AppColors.error"),
        ],
        'download_page.dart': [
            ("foregroundColor: Colors.white)", "foregroundColor: AppColors.primaryLight)"),
            ("return Colors.blue;", "return AppColors.primary;"),
            ("return Colors.red;", "return AppColors.error;"),
            ("return Colors.orange;", "return AppColors.warning;"),
            ("return Colors.green;", "return AppColors.success;"),
            ("Colors.red[400]", "AppColors.error"),
        ],
        'splash_page.dart': [
            ("Container(color: Colors.white)", "Container(color: AppColors.slate50)"),
            ("color: Colors.black45,", "color: AppColors.slate900.withOpacity(0.45),"),
            ("TextStyle(color: Colors.white,", "TextStyle(color: AppColors.primaryLight,"),
            ("Colors.red", "AppColors.error"),
            ("foregroundColor: Colors.white,", "foregroundColor: AppColors.primaryLight,"),
        ],
        'user_center_pages.dart': [
            ("BoxDecoration(color: Colors.white,", "BoxDecoration(color: AppColors.slate50,"),
            ("TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)", "TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight)"),
            ("Icons.play_circle_fill, color: Colors.orange", "Icons.play_circle_fill, color: AppColors.warning"),
            ("TextStyle(color: Colors.orange", "TextStyle(color: AppColors.warning"),
            ("Colors.orange.withOpacity(0.1)", "AppColors.warning.withOpacity(0.1)"),
            ("Colors.orange[50]", "AppColors.warning.withOpacity(0.05)"),
        ],
    }
    
    for filename, replacements in fixes.items():
        path = os.path.join(BASE, 'pages', filename)
        if not os.path.exists(path):
            print(f"  Skip (not found): {path}")
            continue
        content = read_file(path)
        for old, new in replacements:
            content = content.replace(old, new)
        write_file(path, content)
        print(f"Fixed: {path}")

def fix_widgets():
    fixes = {
        'comment_item.dart': [
            ("?? Colors.black;", "?? AppColors.slate900;"),
            ("Colors.black.withOpacity(0.1)", "AppColors.slate900.withOpacity(0.1)"),
            ("color: Colors.black54,", "color: AppColors.slate600,"),
            ("TextStyle(color: Colors.white,", "TextStyle(color: AppColors.primaryLight,"),
            ("Colors.black12", "AppColors.slate200"),
            ("Color(0xFFFF9900)", "AppColors.warning"),
            ("Color(0xFF00C853)", "AppColors.success"),
            ("Colors.red.withOpacity(0.1)", "AppColors.error.withOpacity(0.1)"),
            ("Colors.red.withOpacity(0.5)", "AppColors.error.withOpacity(0.5)"),
            ("color: Colors.red,", "color: AppColors.error,"),
            ("color: Colors.red)", "color: AppColors.error)"),
        ],
        'cast_dialog.dart': [
            ("Icons.cast_connected, color: Colors.white", "Icons.cast_connected, color: AppColors.primaryLight"),
            ("TextStyle(color: Colors.white, fontSize: 18)", "TextStyle(color: AppColors.primaryLight, fontSize: 18)"),
            ("Colors.red.withOpacity(0.2)", "AppColors.error.withOpacity(0.2)"),
            ("Icons.error_outline, color: Colors.red", "Icons.error_outline, color: AppColors.error"),
            ("TextStyle(color: Colors.red,", "TextStyle(color: AppColors.error,"),
            ("Icons.tv_off, color: Colors.white38", "Icons.tv_off, color: AppColors.slate500"),
            ("Colors.white.withOpacity(0.05)", "AppColors.slate50.withOpacity(0.05)"),
            ("TextStyle(color: Colors.white, fontSize: 15)", "TextStyle(color: AppColors.primaryLight, fontSize: 15)"),
            ("Color(0xFF4CAF50)", "AppColors.success"),
            ("return Colors.blue;", "return AppColors.primary;"),
            ("return Colors.purple;", "return AppColors.primaryDark;"),
            ("return Colors.orange;", "return AppColors.warning;"),
            ("return Colors.teal;", "return AppColors.primaryAccent;"),
        ],
        'cast_controls.dart': [
            ("Colors.black.withOpacity(0.85)", "AppColors.slate900.withOpacity(0.85)"),
            ("color: Colors.white,", "color: AppColors.primaryLight,", 1),  # first occurrence only
            ("Color(0xFF4CAF50)", "AppColors.success"),
            ("Colors.white24", "AppColors.slate700.withOpacity(0.24)"),
            ("thumbColor: Colors.white,", "thumbColor: AppColors.primaryLight,"),
            ("Icons.replay_10, color: Colors.white", "Icons.replay_10, color: AppColors.primaryLight"),
            ("AlwaysStoppedAnimation(Colors.white)", "AlwaysStoppedAnimation(AppColors.primaryLight)"),
            ("Icons.forward_10, color: Colors.white", "Icons.forward_10, color: AppColors.primaryLight"),
            ("return Colors.orange;", "return AppColors.warning;"),
            ("return Colors.blue;", "return AppColors.primary;"),
            ("return Colors.red;", "return AppColors.error;"),
        ],
        'custom_player_controls.dart': [
            ("barrierColor: Colors.black54,", "barrierColor: AppColors.slate900.withOpacity(0.54),"),
            ("Color(0xFF4CAF50)", "AppColors.success"),
            ("Color(0xFF66BB6A)", "AppColors.success"),
            ("Colors.white24", "AppColors.slate700.withOpacity(0.24)"),
            ("Colors.white38", "AppColors.slate500.withOpacity(0.38)"),
            ("Colors.black54,", "AppColors.slate900.withOpacity(0.54),"),
            ("Colors.black.withOpacity(0.7)", "AppColors.slate900.withOpacity(0.7)"),
            ("Colors.black.withOpacity(0.85)", "AppColors.slate900.withOpacity(0.85)"),
            ("Colors.black87,", "AppColors.slate900,"),
            ("Colors.black.withOpacity(0.3)", "AppColors.slate900.withOpacity(0.3)"),
            ("Colors.redAccent", "AppColors.error"),
            ("Colors.red", "AppColors.error"),
        ],
    }
    
    for filename, replacements in fixes.items():
        path = os.path.join(BASE, 'widgets', filename)
        if not os.path.exists(path):
            print(f"  Skip (not found): {path}")
            continue
        content = read_file(path)
        for item in replacements:
            if isinstance(item, tuple) and len(item) == 3:
                old, new, count = item
                content = content.replace(old, new, count)
            else:
                old, new = item
                content = content.replace(old, new)
        write_file(path, content)
        print(f"Fixed: {path}")

if __name__ == '__main__':
    print("=== Fixing main pages ===")
    fix_home_page()
    fix_ranking_page()
    fix_profile_page()
    
    print("\n=== Fixing other pages ===")
    fix_other_pages()
    
    print("\n=== Fixing widgets ===")
    fix_widgets()
    
    print("\n=== Done! ===")
