package com.example.lumina

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LuminaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lumina_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "0"))
                setTextViewText(R.id.widget_minutes, widgetData.getString("minutes", ""))
                setTextViewText(R.id.widget_book, widgetData.getString("book", "Lumina"))
                setTextViewText(R.id.widget_hook, widgetData.getString("hook", "Tap to read."))
                setProgressBar(R.id.widget_progress, 100, widgetData.getInt("progress", 0), false)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("lumina://read"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
