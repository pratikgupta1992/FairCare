package com.faircare.app.notify

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.faircare.app.data.ReminderPrefs

/** Fires every hour (inexact); ReminderScheduler decides whether to notify. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderScheduler.maybeNotify(context.applicationContext)
    }
}

/** Re-arm the hourly alarm after a reboot, if reminders are enabled. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val ctx = context.applicationContext
            if (ReminderPrefs(ctx).enabled) {
                ReminderScheduler.ensureChannel(ctx)
                ReminderScheduler.schedule(ctx)
            }
        }
    }
}
