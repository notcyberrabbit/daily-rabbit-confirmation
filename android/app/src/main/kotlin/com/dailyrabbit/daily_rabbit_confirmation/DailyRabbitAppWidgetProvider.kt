package com.dailyrabbit.daily_rabbit_confirmation

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray

/**
 * Daily Rabbit home screen widget (2x2): Affirmation + Task summary.
 */
open class DailyRabbitAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, DailyRabbitWidgetSmall::class.java)
            )
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.dailyrabbit.daily_rabbit_confirmation.UPDATE_WIDGET"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        // Flutter shared_preferences uses "flutter." prefix for keys
        private const val KEY_AFFIRMATION = "flutter.daily_rabbit_widget_affirmation"
        private const val KEY_TASKS = "flutter.daily_rabbit_tasks"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val affirmation = prefs.getString(KEY_AFFIRMATION, null)
                ?: context.getString(R.string.widget_default_affirmation)
            val tasksJson = prefs.getString(KEY_TASKS, null)
            val taskSummary = formatTaskSummary(context, tasksJson)

            val clickIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, android.app.Activity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.widget_small).apply {
                setTextViewText(R.id.widget_affirmation, affirmation)
                setTextViewText(R.id.widget_task_summary, taskSummary)
                setOnClickPendingIntent(R.id.widget_affirmation, pendingIntent)
                setOnClickPendingIntent(R.id.widget_task_summary, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun formatTaskSummary(context: Context, tasksJson: String?): String {
            if (tasksJson.isNullOrBlank()) return context.getString(R.string.widget_default_tasks)
            return try {
                val arr = JSONArray(tasksJson)
                val total = arr.length()
                var completed = 0
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i)
                    if (obj?.optBoolean("completed", false) == true) completed++
                }
                "$completed/$total completed"
            } catch (_: Exception) {
                context.getString(R.string.widget_default_tasks)
            }
        }
    }
}
