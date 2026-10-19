package com.suwar.suwar

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.concurrent.Executors

/** User-selected Storage Access Framework documents; no broad storage permission. */
class BackupDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var content: ByteArray? = null
    private var saving = false
    private val limit = 2 * 1024 * 1024

    init {
        MethodChannel(messenger, "suwar/backup_files").setMethodCallHandler { call, result ->
            if (pending != null) {
                result.error("busy", "A document operation is already open", null)
                return@setMethodCallHandler
            }
            try {
                val intent: Intent
                when (call.method) {
                    "saveBackup" -> {
                        val text = call.argument<String>("contents") ?: error("Missing contents")
                        val bytes = text.toByteArray(Charsets.UTF_8)
                        require(bytes.size <= limit) { "Backup is too large" }
                        content = bytes
                        saving = true
                        intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            type = "application/json"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "suwar-backup.json")
                        }
                    }
                    "openBackup" -> {
                        saving = false
                        intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "*/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                        }
                    }
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                pending = result
                activity.startActivityForResult(intent, REQUEST)
            } catch (e: Exception) {
                pending = null
                content = null
                result.error("document", "Unable to open document picker", null)
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            content = null
            result.success(if (saving) false else null)
            return true
        }
        val bytes = content
        val isSave = saving
        executor.execute {
            try {
                val value: Any? = if (isSave) {
                    val output = activity.contentResolver.openOutputStream(uri, "wt") ?: error("Unavailable document")
                    output.use { it.write(bytes ?: error("Missing contents")); it.flush() }
                    true
                } else {
                    val input = activity.contentResolver.openInputStream(uri) ?: error("Unavailable document")
                    val loaded = input.use { stream ->
                        val output = java.io.ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = stream.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= limit) { "Backup exceeds limit" }
                            output.write(buffer, 0, count)
                        }
                        output.toByteArray()
                    }
                    Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(loaded)).toString()
                }
                main.post { pending = null; content = null; result.success(value) }
            } catch (e: Exception) {
                main.post { pending = null; content = null; result.error("document", "Unable to read or write backup document", null) }
            }
        }
        return true
    }

    companion object { private const val REQUEST = 7241 }
}
