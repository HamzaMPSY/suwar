package com.suwar.suwar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.view.View
import android.widget.RemoteViews

object AyahWidgetRenderer {
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, AyahWidgetProvider::class.java))
        for (id in ids) {
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300).coerceAtLeast(120)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 220).coerceAtLeast(80)
            val views = RemoteViews(context.packageName, R.layout.ayah_widget)
            try {
                val verse = AyahWidgetStore.selected(context, compact = width < 260 || height < 200)
                views.setTextViewText(R.id.ayah_widget_topic, "سُوَر · ${AyahWidgetStore.topics[verse.topic]}")
                views.setTextViewText(R.id.ayah_widget_reference, verse.reference)
                // RemoteViews cannot load a custom typeface. Render with the bundled
                // Warsh font, and expose the full lexical text to accessibility.
                val bitmap = render(context, verse.lexical, width - 32, height - 132)
                views.setViewVisibility(R.id.ayah_widget_image, if (bitmap != null) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.ayah_widget_message, if (bitmap == null) View.VISIBLE else View.GONE)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.ayah_widget_image, bitmap)
                    views.setContentDescription(R.id.ayah_widget_image, verse.lexical + "، " + verse.reference)
                } else {
                    views.setTextViewText(R.id.ayah_widget_message, "كبّر الأداة لقراءة الآية كاملة")
                }
                val open = Intent(context, MainActivity::class.java).setAction(AyahWidgetProvider.openAction)
                    .putExtra("ayahId", verse.id).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                views.setOnClickPendingIntent(R.id.ayah_widget_root, PendingIntent.getActivity(context, id + 61000, open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                val next = Intent(context, AyahWidgetProvider::class.java).setAction(AyahWidgetProvider.nextAction)
                views.setOnClickPendingIntent(R.id.ayah_widget_next, PendingIntent.getBroadcast(context, 61001, next,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            } catch (_: Exception) {
                views.setViewVisibility(R.id.ayah_widget_image, View.GONE)
                views.setViewVisibility(R.id.ayah_widget_message, View.VISIBLE)
                views.setTextViewText(R.id.ayah_widget_message, "افتح سُوَر لتحديث الأداة")
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun render(context: Context, text: String, widthDp: Int, heightDp: Int): Bitmap? {
        if (widthDp < 100 || heightDp < 32 || Build.VERSION.SDK_INT < 23) return null
        val width = (widthDp * 2).coerceAtMost(640)
        val height = (heightDp * 2).coerceAtMost(400)
        val scale = width.toFloat() / widthDp
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(23, 63, 53)
            typeface = Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/warsh.10.ttf")
        }
        for (size in 28 downTo 18) {
            paint.textSize = size * scale
            val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_CENTER).setTextDirection(TextDirectionHeuristics.RTL)
                .setIncludePad(true).setLineSpacing(paint.textSize * .25f, 1f).build()
            if (layout.height > height) continue
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.translate(0f, (height - layout.height) / 2f)
            layout.draw(canvas)
            return bitmap
        }
        // Never ellipsize, clip or substitute a fragment of an ayah.
        return null
    }
}
