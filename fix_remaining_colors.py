import os

BASE = r'e:\phpstudy_pro\WWW\ys\ys_movie_app\lib'

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_remaining():
    # === search_page.dart ===
    path = os.path.join(BASE, 'pages', 'search_page.dart')
    content = read_file(path)
    
    # Replace colorful hot keyword tags with AppColors-based theme colors
    old_colors = """                final color = [
                  Colors.redAccent, Colors.orangeAccent, Colors.blueAccent, 
                  Colors.greenAccent, Colors.purpleAccent, Colors.teal, 
                  Colors.pinkAccent, Colors.amber
                ][index % 8].withOpacity(0.15);
                final textColor = [
                  Colors.red, Colors.orange[800]!, Colors.blue, 
                  Colors.green[700]!, Colors.purple, Colors.teal[700]!, 
                  Colors.pink, Colors.amber[900]!
                ][index % 8];"""
    
    new_colors = """                final color = [
                  AppColors.error, AppColors.warning, AppColors.primary, 
                  AppColors.success, AppColors.primaryDark, AppColors.primaryAccent, 
                  AppColors.primaryLight, AppColors.warning
                ][index % 8].withOpacity(0.15);
                final textColor = [
                  AppColors.error, AppColors.warning, AppColors.primary, 
                  AppColors.success, AppColors.primaryDark, AppColors.primaryAccent, 
                  AppColors.primaryLight, AppColors.warning
                ][index % 8];"""
    
    content = content.replace(old_colors, new_colors)
    
    # Colors.black87 -> AppColors.slate900
    content = content.replace("Colors.black87", "AppColors.slate900")
    
    write_file(path, content)
    print(f"Fixed: {path}")
    
    # === vod_list_page.dart ===
    path = os.path.join(BASE, 'pages', 'vod_list_page.dart')
    content = read_file(path)
    
    content = content.replace("Colors.white38 : Colors.black38", "AppColors.slate500 : AppColors.slate600")
    content = content.replace("Colors.white38 : Colors.black38", "AppColors.slate500 : AppColors.slate600")
    
    write_file(path, content)
    print(f"Fixed: {path}")
    
    # === user_center_pages.dart ===
    path = os.path.join(BASE, 'pages', 'user_center_pages.dart')
    content = read_file(path)
    
    content = content.replace("Colors.black54", "AppColors.slate600")
    content = content.replace("color: isAdd ? Colors.red : Colors.green", "color: isAdd ? AppColors.error : AppColors.success")
    content = content.replace("TextStyle(color: Colors.blue", "TextStyle(color: AppColors.primary")
    content = content.replace("TextStyle(fontSize: 12, color: Colors.green)", "TextStyle(fontSize: 12, color: AppColors.success)")
    content = content.replace("color: Colors.white, fontSize: 32", "color: AppColors.primaryLight, fontSize: 32")
    
    write_file(path, content)
    print(f"Fixed: {path}")
    
    # === detail_page.dart ===
    path = os.path.join(BASE, 'pages', 'detail_page.dart')
    content = read_file(path)
    
    # Colors.black fallback -> AppColors.slate900
    content = content.replace("?? Colors.black;", "?? AppColors.slate900;")
    
    # Colors.white on primary button foreground is OK, but let's use AppColors.textInverse
    # Actually, Colors.white on primary buttons is standard Flutter practice, leave it
    
    write_file(path, content)
    print(f"Fixed: {path}")
    
    # === home_page.dart - fix shimmer Colors.white ===
    path = os.path.join(BASE, 'pages', 'home_page.dart')
    content = read_file(path)
    
    # Fix shimmer placeholder color
    content = content.replace(
        "color: Colors.white,\n            borderRadius: BorderRadius.circular(20),",
        "color: AppColors.slate50,\n            borderRadius: BorderRadius.circular(20),"
    )
    content = content.replace(
        "color: Colors.white,\n            borderRadius: BorderRadius.circular(8),",
        "color: AppColors.slate50,\n            borderRadius: BorderRadius.circular(8),"
    )
    
    write_file(path, content)
    print(f"Fixed: {path}")
    
    # === slide_banner.dart ===
    path = os.path.join(BASE, 'widgets', 'slide_banner.dart')
    if os.path.exists(path):
        content = read_file(path)
        content = content.replace("? Colors.white\n", "? AppColors.primaryLight\n")
        write_file(path, content)
        print(f"Fixed: {path}")
    
    # === login_page.dart ===
    path = os.path.join(BASE, 'pages', 'login_page.dart')
    if os.path.exists(path):
        content = read_file(path)
        # foregroundColor: Colors.white on primary button is standard, leave it
        # But CircularProgressIndicator color should be AppColors.primaryLight
        content = content.replace(
            "CircularProgressIndicator(color: Colors.white, strokeWidth: 2)",
            "CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2)"
        )
        write_file(path, content)
        print(f"Fixed: {path}")

if __name__ == '__main__':
    fix_remaining()
    print("\n=== Done! ===")
