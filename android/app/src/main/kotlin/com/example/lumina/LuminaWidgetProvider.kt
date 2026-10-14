package com.example.lumina

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

class LuminaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // Minutes are for the day the app last wrote them. On a new day the
        // count starts again at zero.
        val stale = widgetData.getString("widgetDate", null)
            ?.let { it != LocalDate.now().toString() } ?: false
        val minutes = if (stale) {
            "0 of ${widgetData.getInt("goalMinutes", 10)} min"
        } else {
            widgetData.getString("minutes", "")
        }
        val progress = if (stale) 0 else widgetData.getInt("progress", 0)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lumina_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "0"))
                setTextViewText(R.id.widget_minutes, minutes)
                setTextViewText(R.id.widget_book, widgetData.getString("book", "Lumina"))
                setTextViewText(R.id.widget_hook, widgetData.getString("hook", "Tap to read."))
                setProgressBar(R.id.widget_progress, 100, progress, false)
                // The drawn card shows the day it was made, so it is only used
                // while it is still that day.
                val card = if (stale) {
                    null
                } else {
                    widgetData.getString("todayCard", null)
                        ?.let { BitmapFactory.decodeFile(it) }
                }
                if (card != null) {
                    setImageViewBitmap(R.id.widget_image, card)
                    setViewVisibility(R.id.widget_image, View.VISIBLE)
                    setViewVisibility(R.id.widget_fallback, View.INVISIBLE)
                } else {
                    setViewVisibility(R.id.widget_image, View.GONE)
                    setViewVisibility(R.id.widget_fallback, View.VISIBLE)
                }
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
