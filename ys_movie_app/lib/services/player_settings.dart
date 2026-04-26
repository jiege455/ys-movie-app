import 'package:flutter/foundation.dart';
import 'store.dart';

class PlayerSettings extends ChangeNotifier {
  // 弹幕设置
  bool _danmakuEnabled = true;
  bool get danmakuEnabled => _danmakuEnabled;

  // 新增：弹幕显示区域 (0.25 ~ 1.0)
  double _danmakuArea = 0.5;
  double get danmakuArea => _danmakuArea;

  // 新增：弹幕透明度 (0.1 ~ 1.0)
  double _danmakuOpacity = 1.0;
  double get danmakuOpacity => _danmakuOpacity;

  // 新增：弹幕字体大小 (10 ~ 30)
  double _danmakuFontSize = 18.0;
  double get danmakuFontSize => _danmakuFontSize;

  // 新增：弹幕速度 (0.5 ~ 2.0)
  double _danmakuSpeed = 1.0;
  double get danmakuSpeed => _danmakuSpeed;

  // 新增：滚动行数 (1 ~ 20)
  double _danmakuScrollRows = 5.0; // 默认减半，只占屏幕上方区域
  double get danmakuScrollRows => _danmakuScrollRows;

  // 新增：顶部行数 (0 ~ 10)
  double _danmakuTopRows = 0.0;
  double get danmakuTopRows => _danmakuTopRows;

  // 新增：底部行数 (0 ~ 10)
  double _danmakuBottomRows = 0.0;
  double get danmakuBottomRows => _danmakuBottomRows;

  // 跳过设置
  bool _enableSkip = false;
  bool get enableSkip => _enableSkip;

  int _skipIntro = 0; // 片头秒数
  int get skipIntro => _skipIntro;

  int _skipOutro = 0; // 片尾秒数
  int get skipOutro => _skipOutro;

  // 画面比例 (0:默认, 1:16:9, 2:4:3, 3:铺满)
  int _aspectRatioMode = 0;
  int get aspectRatioMode => _aspectRatioMode;

  // 新增：播放速度
  double _speed = 1.0;
  double get speed => _speed;

  // 单例模式
  static final PlayerSettings _instance = PlayerSettings._internal();
  factory PlayerSettings() => _instance;
  PlayerSettings._internal() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _danmakuEnabled = await StoreService.getDanmakuEnabled();
    _enableSkip = await StoreService.getSkipEnabled();
    _skipIntro = await StoreService.getSkipIntroSeconds();
    _skipOutro = await StoreService.getSkipEndingSeconds();
    _speed = await StoreService.getPlaybackSpeed();
    notifyListeners();
  }

  void setDanmakuEnabled(bool value) {
    if (_danmakuEnabled != value) {
      _danmakuEnabled = value;
      StoreService.setDanmakuEnabled(value);
      notifyListeners();
    }
  }

  // 新增：设置弹幕显示区域的方法
  void setDanmakuArea(double value) {
    if (_danmakuArea != value) {
      _danmakuArea = value;
      notifyListeners();
    }
  }

  // 新增：设置透明度的方法
  void setDanmakuOpacity(double value) {
    if (_danmakuOpacity != value) {
      _danmakuOpacity = value;
      notifyListeners();
    }
  }

  void setDanmakuFontSize(double value) {
    if (_danmakuFontSize != value) {
      _danmakuFontSize = value;
      notifyListeners();
    }
  }

  void setDanmakuSpeed(double value) {
    if (_danmakuSpeed != value) {
      _danmakuSpeed = value;
      notifyListeners();
    }
  }

  void setDanmakuScrollRows(double value) {
    if (_danmakuScrollRows != value) {
      _danmakuScrollRows = value;
      notifyListeners();
    }
  }

  void setDanmakuTopRows(double value) {
    if (_danmakuTopRows != value) {
      _danmakuTopRows = value;
      notifyListeners();
    }
  }

  void setDanmakuBottomRows(double value) {
    if (_danmakuBottomRows != value) {
      _danmakuBottomRows = value;
      notifyListeners();
    }
  }

  void setEnableSkip(bool value) {
    if (_enableSkip != value) {
      _enableSkip = value;
      StoreService.setSkipEnabled(value);
      notifyListeners();
    }
  }

  void setSkipIntro(int seconds) {
    if (_skipIntro != seconds) {
      _skipIntro = seconds;
      StoreService.setSkipIntroSeconds(seconds);
      notifyListeners();
    }
  }

  void setSkipOutro(int seconds) {
    if (_skipOutro != seconds) {
      _skipOutro = seconds;
      StoreService.setSkipEndingSeconds(seconds);
      notifyListeners();
    }
  }

  void setAspectRatioMode(int mode) {
    if (_aspectRatioMode != mode) {
      _aspectRatioMode = mode;
      notifyListeners();
    }
  }

  void setSpeed(double value) {
    if (_speed != value) {
      _speed = value;
      StoreService.setPlaybackSpeed(value);
      notifyListeners();
    }
  }
}
