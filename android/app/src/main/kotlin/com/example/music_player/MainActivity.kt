package com.example.music_player




import android.provider.Settings
import android.util.Log
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/layout_direction"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isRtl" -> {
                    val forcedRtl = try {
                        Settings.Global.getInt(
                            contentResolver,
                            "debug.force_rtl",
                            0
                        ) != 0
                    } catch (exception: Exception) {
                        Log.w("FlutterRTL", "Couldn't read force RTL setting", exception)
                        false
                    }

                    val configRtl =
                        resources.configuration.layoutDirection ==
                            View.LAYOUT_DIRECTION_RTL

                    val windowRtl =
                        window.decorView.layoutDirection ==
                            View.LAYOUT_DIRECTION_RTL

                    Log.d(
                        "FlutterRTL",
                        "force=$forcedRtl config=$configRtl window=$windowRtl"
                    )

                    result.success(forcedRtl || configRtl || windowRtl)
                }

                else -> result.notImplemented()
            }
        }
    }
}