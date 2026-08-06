package com.example.gdself

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity  // ✅ Ganti import ini
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {  // ✅ Ganti di sini
    private val CHANNEL = "com.example.gdself/health_connect"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openHealthConnectSettings") {
                var opened = false

                if (!opened) {
                    try {
                        val intent = Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
                        intent.putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                if (!opened) {
                    try {
                        val intent = Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS")
                        intent.putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                if (!opened) {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                if (opened) {
                    result.success(true)
                } else {
                    result.error("UNAVAILABLE", "Gagal membuka pengaturan perizinan", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}