package com.inteli.rehab

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Calendar
import java.util.TimeZone

/// The daily exercise reminder, done here instead of with a plugin (same reason as the other device
/// helpers in MainActivity.kt).
///
/// The patient picks a time. At that time each day the receiver below shows a notification - unless they
/// have already exercised recently enough: `intervalDays` comes from the plan's frequency ("Daily" = 1,
/// "Every other day" = 2, "Weekly" = 7) and `lastDoneDay` is the last day a session was finished, so a
/// patient on a weekly plan is not nagged daily and one who exercised today is not nagged at all.
///
/// Settings live in SharedPreferences so the alarm can be set again after a reboot (BootReceiver) without
/// the app running.
object Reminders {
    private const val PREFS = "reminders"
    private const val CHANNEL_ID = "exercise_reminders"
    private const val REQUEST_CODE = 4107

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /// Days since 1970 in the phone's own time zone, so "today" means the patient's today.
    fun epochDay(nowMs: Long = System.currentTimeMillis()): Long =
        (nowMs + TimeZone.getDefault().getOffset(nowMs)) / 86_400_000L

    fun read(context: Context): Map<String, Any> {
        val p = prefs(context)
        return mapOf(
            "enabled" to p.getBoolean("enabled", false),
            "hour" to p.getInt("hour", 18),
            "minute" to p.getInt("minute", 0),
            "intervalDays" to p.getInt("intervalDays", 1),
        )
    }

    fun set(context: Context, hour: Int, minute: Int, intervalDays: Int) {
        prefs(context).edit()
            .putBoolean("enabled", true)
            .putInt("hour", hour.coerceIn(0, 23))
            .putInt("minute", minute.coerceIn(0, 59))
            .putInt("intervalDays", intervalDays.coerceAtLeast(1))
            .apply()
        schedule(context)
    }

    fun cancel(context: Context) {
        prefs(context).edit().putBoolean("enabled", false).apply()
        alarmManager(context).cancel(pendingIntent(context))
    }

    fun setIntervalDays(context: Context, days: Int) {
        prefs(context).edit().putInt("intervalDays", days.coerceAtLeast(1)).apply()
    }

    fun markSessionDone(context: Context) {
        prefs(context).edit().putLong("lastDoneDay", epochDay()).apply()
    }

    private fun alarmManager(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, ReminderReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /// Sets the next alarm: today at the chosen time if that is still ahead, otherwise tomorrow. An
    /// inexact alarm (which may fire a little late in battery saving) so no exact-alarm permission is needed.
    fun schedule(context: Context) {
        val p = prefs(context)
        if (!p.getBoolean("enabled", false)) return
        val at = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, p.getInt("hour", 18))
            set(Calendar.MINUTE, p.getInt("minute", 0))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarmManager(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.timeInMillis, pendingIntent(context))
    }

    /// Whether today's reminder should be shown: only if a session is due under the plan's frequency.
    fun isDue(context: Context): Boolean {
        val p = prefs(context)
        val last = p.getLong("lastDoneDay", -1L)
        if (last < 0) return true
        return epochDay() - last >= p.getInt("intervalDays", 1)
    }

    fun notifyNow(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return // the patient turned them off in system settings
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Exercise reminders", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val open = PendingIntent.getActivity(
            context,
            REQUEST_CODE,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Time for your exercises")
            .setContentText("Your physiotherapist's plan is ready when you are.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(REQUEST_CODE, notification)
    }
}

/// The alarm went off: remind if a session is due, then set tomorrow's alarm.
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Reminders.isDue(context)) Reminders.notifyNow(context)
        Reminders.schedule(context)
    }
}

/// Alarms are forgotten when the phone restarts; set it again.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.schedule(context)
    }
}
