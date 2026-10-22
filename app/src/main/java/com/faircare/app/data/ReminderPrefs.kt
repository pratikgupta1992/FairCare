package com.faircare.app.data

import android.content.Context
import java.util.Calendar

/** Hourly reminder preferences: on/off + quiet hours (no nudges overnight). */
class ReminderPrefs(context: Context) {
    private val p = context.getSharedPreferences("faircare_reminders", Context.MODE_PRIVATE)

    var enabled: Boolean
        get() = p.getBoolean("enabled", false)
        set(v) { p.edit().putBoolean("enabled", v).apply() }

    /** minutes since midnight; default 10:00 PM */
    var quietStartMin: Int
        get() = p.getInt("quiet_start", 22 * 60)
        set(v) { p.edit().putInt("quiet_start", v).apply() }

    /** minutes since midnight; default 7:00 AM */
    var quietEndMin: Int
        get() = p.getInt("quiet_end", 7 * 60)
        set(v) { p.edit().putInt("quiet_end", v).apply() }

    fun isQuietNow(nowMin: Int = currentMinutes()): Boolean {
        val s = quietStartMin
        val e = quietEndMin
        return if (s <= e) nowMin in s until e else nowMin >= s || nowMin < e
    }

    companion object {
        fun currentMinutes(): Int {
            val cal = Calendar.getInstance()
            return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        }

        /** 22*60 -> "10:00 PM" */
        fun fmt(min: Int): String {
            val h24 = (min / 60) % 24
            val m = min % 60
            val ampm = if (h24 < 12) "AM" else "PM"
            val h12 = when (val h = h24 % 12) {
                0 -> 12
                else -> h
            }
            return "%d:%02d %s".format(h12, m, ampm)
        }
    }
}
