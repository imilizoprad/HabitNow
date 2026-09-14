package com.habitnow.arena

import android.Manifest
import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host for the single platform channel the app uses
 * (`habit_now/platform`): app-private storage path + habit reminders.
 *
 * Everything else in this app — networking, persistence, scoring — lives
 * in Dart. No plugins, no third-party dependencies.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        acquireMulticastLock()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "habit_now/platform",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)

                "scheduleReminder" -> {
                    val id = (call.argument<Number>("id") ?: 0).toInt()
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val at = (call.argument<Number>("at") ?: 0).toLong()
                    val weekdays =
                        (call.argument<List<Number>>("weekdays") ?: emptyList())
                            .map { it.toInt() }
                    requestNotificationPermissionIfNeeded()
                    ReminderScheduler.schedule(this, id, title, body, at, weekdays)
                    result.success(null)
                }

                "cancelReminder" -> {
                    val id = (call.argument<Number>("id") ?: 0).toInt()
                    ReminderScheduler.cancel(this, id)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * UDP broadcast reception is gated behind multicast filtering on many
     * devices — without this lock, peer discovery silently misses peers.
     */
    private fun acquireMulticastLock() {
        if (MainActivity.multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifi == null) {
            MainActivity.multicastLock = null
            return
        }
        val lock = wifi.createMulticastLock("habitnow_discovery").apply {
            setReferenceCounted(false)
            acquire()
        }
        MainActivity.multicastLock = lock
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            if (granted != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 40101)
            }
        }
    }

    companion object {
        @Volatile
        var multicastLock: WifiManager.MulticastLock? = null
    }
}
