package com.devparadise.nook

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NookWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.nook_widget).apply {
                val summary = widgetData.getString(
                    "pinned_summary",
                    "Tap + to capture a thought"
                ) ?: "Tap + to capture a thought"
                setTextViewText(R.id.nook_widget_summary, summary)

                val captureIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("nook://capture?type=text")
                )
                setOnClickPendingIntent(R.id.nook_widget_capture_btn, captureIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
