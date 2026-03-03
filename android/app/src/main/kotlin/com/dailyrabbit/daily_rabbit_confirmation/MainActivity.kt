package com.dailyrabbit.daily_rabbit_confirmation

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.dailyrabbit.daily_rabbit_confirmation/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val intent = Intent(DailyRabbitAppWidgetProvider.ACTION_UPDATE_WIDGET).apply {
                    setPackage(packageName)
                }
                sendBroadcast(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
