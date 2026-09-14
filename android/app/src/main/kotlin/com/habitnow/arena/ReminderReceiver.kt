package com.habitnow.arena

import android.Manifest
import android.app.Notification
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * Fires the reminder notification and chains the next occurrence for
 * weekday-habits so a daily habit keeps nudging without the app running.
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "Habit time"
        val body = intent.getStringExtra("body") ?: ""
        val at = intent.getLongExtra("at", 0L)
        val weekdays =
            intent.getIntArrayExtra("weekdays")?.toList() ?: emptyList()

        if (Build.VERSION.SDK_INT >= 33) {
            val granted = context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS,
            )
            if (granted != PackageManager.PERMISSION_GRANTED) {
                // Can't surface it — but keep the chain alive anyway.
                rescheduleNext(context, id, title, body, at, weekdays)
                return
            }
        }

        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, "habit_reminders")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)

        val open = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        if (open != null) {
            val contentPi = PendingIntent.getActivity(
                context,
                id,
                open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.setContentIntent(contentPi)
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? android.app.NotificationManager
        nm?.notify(id, builder.build())

        rescheduleNext(context, id, title, body, at, weekdays)
    }

    private fun rescheduleNext(
        context: Context,
        id: Int,
        title: String,
        body: String,
        atMs: Long,
        weekdays: List<Int>,
    ) {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = atMs }
        val minuteOfDay = if (atMs > 0) {
            cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
                cal.get(java.util.Calendar.MINUTE)
        } else {
            8 * 60
        }
        val next = ReminderScheduler.nextOccurrence(
            System.currentTimeMillis(),
            minuteOfDay,
            weekdays,
        )
        ReminderScheduler.setAlarm(context, id, title, body, next, weekdays)
    }
}
