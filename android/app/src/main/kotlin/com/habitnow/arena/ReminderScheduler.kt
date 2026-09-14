package com.habitnow.arena

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.io.File
import java.util.Calendar
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject

/**
 * Exact-in-intent, best-effort-in-practice reminder scheduling.
 *
 * Alarms fire [ReminderReceiver], which shows the notification and chains
 * the next occurrence for weekday-habits. The schedule is also mirrored to
 * `filesDir/reminders.json` so [BootReceiver] can restore everything after
 * a reboot without asking Dart for help.
 */
object ReminderScheduler {

    private const val CHANNEL_ID = "habit_reminders"
    private const val STORE = "reminders.json"

    fun schedule(
        context: Context,
        id: Int,
        title: String,
        body: String,
        atMs: Long,
        weekdays: List<Int>,
    ) {
        ensureChannel(context)
        persist(context, id, title, body, atMs, weekdays)
        setAlarm(context, id, title, body, atMs, weekdays)
    }

    fun cancel(context: Context, id: Int) {
        removePersisted(context, id)
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pendingIntent(context, id, "", "", emptyList(), 0L)
        am.cancel(pi)
    }

    /** Recomputes the next due time for a weekday-habit after [afterMs]. */
    fun nextOccurrence(afterMs: Long, minuteOfDay: Int, weekdays: List<Int>): Long {
        val days = if (weekdays.isEmpty()) listOf(1, 2, 3, 4, 5, 6, 7) else weekdays
        var candidate = Calendar.getInstance().apply {
            timeInMillis = afterMs
            set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
            set(Calendar.MINUTE, minuteOfDay % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.MINUTE, 1) // strictly in the future
        }
        // Monday-based Dart weekday (1..7) → Calendar.DAY_OF_WEEK (1..7, Sun=1).
        for (i in 0 until 8) {
            val dartWeekday = when (candidate.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                else -> 7
            }
            if (days.contains(dartWeekday) && candidate.timeInMillis > afterMs) {
                return candidate.timeInMillis
            }
            candidate = (candidate.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        return afterMs + TimeUnit.DAYS.toMillis(1)
    }

    fun setAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        atMs: Long,
        weekdays: List<Int>,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pendingIntent(context, id, title, body, weekdays, atMs)
        val canExact =
            Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        if (canExact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pi)
        }
    }

    private fun pendingIntent(
        context: Context,
        id: Int,
        title: String,
        body: String,
        weekdays: List<Int>,
        atMs: Long,
    ): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction("com.habitnow.arena.REMINDER_$id")
            .putExtra("id", id)
            .putExtra("title", title)
            .putExtra("body", body)
            .putExtra("at", atMs)
            .putExtra("weekdays", weekdays.toIntArray())
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Habit reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Nudges to keep your streaks alive"
            setShowBadge(true)
        }
        nm?.createNotificationChannel(channel)
    }

    // -- persistence (plain JSON in filesDir; readable after reboot) --------

    private fun storeFile(context: Context): File = File(context.filesDir, STORE)

    private fun readAll(context: Context): JSONArray = try {
        JSONArray(storeFile(context).readText())
    } catch (e: Exception) {
        JSONArray()
    }

    private fun writeAll(context: Context, array: JSONArray) {
        storeFile(context).writeText(array.toString())
    }

    @Synchronized
    private fun persist(
        context: Context,
        id: Int,
        title: String,
        body: String,
        atMs: Long,
        weekdays: List<Int>,
    ) {
        val all = readAll(context)
        val cleaned = JSONArray()
        for (i in 0 until all.length()) {
            val o = all.optJSONObject(i) ?: continue
            if (o.optInt("id") != id) cleaned.put(o)
        }
        val cal = Calendar.getInstance().apply { timeInMillis = atMs }
        cleaned.put(
            JSONObject()
                .put("id", id)
                .put("title", title)
                .put("body", body)
                .put("minuteOfDay", cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE))
                .put("weekdays", JSONArray(weekdays)),
        )
        writeAll(context, cleaned)
    }

    @Synchronized
    private fun removePersisted(context: Context, id: Int) {
        val all = readAll(context)
        val cleaned = JSONArray()
        for (i in 0 until all.length()) {
            val o = all.optJSONObject(i) ?: continue
            if (o.optInt("id") != id) cleaned.put(o)
        }
        writeAll(context, cleaned)
    }

    fun readPersisted(context: Context): List<PersistedReminder> {
        val all = readAll(context)
        val out = ArrayList<PersistedReminder>(all.length())
        for (i in 0 until all.length()) {
            val o = all.optJSONObject(i) ?: continue
            val days = ArrayList<Int>()
            val arr = o.optJSONArray("weekdays") ?: JSONArray()
            for (j in 0 until arr.length()) days.add(arr.optInt(j))
            out.add(
                PersistedReminder(
                    id = o.optInt("id"),
                    title = o.optString("title"),
                    body = o.optString("body"),
                    minuteOfDay = o.optInt("minuteOfDay"),
                    weekdays = days,
                ),
            )
        }
        return out
    }

    data class PersistedReminder(
        val id: Int,
        val title: String,
        val body: String,
        val minuteOfDay: Int,
        val weekdays: List<Int>,
    )
}
