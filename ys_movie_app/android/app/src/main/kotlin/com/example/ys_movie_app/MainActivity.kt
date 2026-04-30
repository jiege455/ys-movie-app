package com.example.ys_movie_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 开发者：杰哥网络科技 (qq: 2711793818)
 * 主Activity - 注册投屏插件
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册投屏插件
        CastPlugin.registerWith(flutterEngine, this)
    }
}
