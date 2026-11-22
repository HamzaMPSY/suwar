package com.suwar.suwar

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var prayerWidgetChannel: PrayerWidgetChannel? = null
    private var ayahWidgetChannel: AyahWidgetChannel? = null
    private var backupDocuments: BackupDocuments? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        prayerWidgetChannel = PrayerWidgetChannel(this, messenger)
        prayerWidgetChannel?.handleIntent(intent)
        ayahWidgetChannel = AyahWidgetChannel(this, messenger)
        ayahWidgetChannel?.handleIntent(intent)
        backupDocuments = BackupDocuments(this, messenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        ayahWidgetChannel?.handleIntent(intent)
        prayerWidgetChannel?.handleIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupDocuments?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
