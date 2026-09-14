package com.habitnow.arena

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restores all habit reminders after a reboot, straight from the persisted
 * schedule — no Flutter engine spin-up required.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val now = System.currentTimeMillis()
        for (r in ReminderScheduler.readPersisted(context)) {
            val next = ReminderScheduler.nextOccurrence(now, r.minuteOfDay, r.weekdays)
            ReminderScheduler.setAlarm(context, r.id, r.title, r.body, next, r.weekdays)
        }
    }
}
