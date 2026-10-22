package com.faircare.app.notify

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.faircare.app.MainActivity
import com.faircare.app.R
import com.faircare.app.data.Db
import com.faircare.app.data.ReminderPrefs

/** Hourly logging nudges. Inexact alarms = battery-friendly; the receiver
 *  itself enforces quiet hours and skips hours that are already logged. */
object ReminderScheduler {
    const val CHANNEL_ID = "logging_reminders"
    const val EXTRA_OPEN_LOG = "extra_open_log"
    private const val REQ_ALARM = 1001
    private const val NOTIF_ID = 2001

    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val first = now - now % 3_600_000L + 3_600_000L // next hour boundary
        am.setInexactRepeating(
            AlarmManager.RTC_WAKEUP, first, AlarmManager.INTERVAL_HOUR, alarmPending(ctx)
        )
    }

    fun cancel(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmPending(ctx))
    }

    private fun alarmPending(ctx: Context): PendingIntent {
        val i = Intent(ctx, ReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            ctx, REQ_ALARM, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Logging reminders",
                        NotificationManager.IMPORTANCE_DEFAULT
                    )
                )
            }
        }
    }

    /** Called by ReminderReceiver each hour. Shows nothing during quiet hours
     *  or when the current hour already has a log entry. */
    fun maybeNotify(ctx: Context) {
        val prefs = ReminderPrefs(ctx)
        if (!prefs.enabled) return
        if (prefs.isQuietNow()) return

        // Smart skip: don't nag when this hour is already logged.
        val now = System.currentTimeMillis()
        val hStart = now - now % 3_600_000L
        if (Db.get(ctx).getLogs(hStart, hStart + 3_600_000L, null).isNotEmpty()) return

        ensureChannel(ctx)
        val open = Intent(ctx, MainActivity::class.java).apply {
            putExtra(EXTRA_OPEN_LOG, true)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val openPi = PendingIntent.getActivity(
            ctx, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle("Time to log care")
            .setContentText("Who's been with the baby this hour? Tap to log it.")
            .setContentIntent(openPi)
            .setAutoCancel(true)
            .build()
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIF_ID, notif)
    }
}
