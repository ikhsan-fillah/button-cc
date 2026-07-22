package com.kkn.cerdascermatbuzzer

import android.os.Build
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permissionsChannel = "cerdas_cermat_buzzer/permissions"
    private val localNetworkPermission = "android.permission.ACCESS_LOCAL_NETWORK"
    private val requestLocalNetworkCode = 4040
    private var pendingLocalNetworkResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestLocalNetwork" -> requestLocalNetworkPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestLocalNetworkPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 36) {
            result.success(true)
            return
        }

        if (checkSelfPermission(localNetworkPermission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        pendingLocalNetworkResult = result
        requestPermissions(arrayOf(localNetworkPermission), requestLocalNetworkCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == requestLocalNetworkCode) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pendingLocalNetworkResult?.success(granted)
            pendingLocalNetworkResult = null
        }
    }
}
