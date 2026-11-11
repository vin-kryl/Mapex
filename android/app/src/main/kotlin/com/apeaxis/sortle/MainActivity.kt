package com.apeaxis.sortle

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Hands board files opened from Files or shared from another app to the
/// Dart side on the "sortle/files" channel.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val queued = mutableListOf<Map<String, Any>>()
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sortle/files").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeQueued") {
                    dartReady = true
                    result.success(queued.toList())
                    queued.clear()
                } else {
                    result.notImplemented()
                }
            }
        }
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        if (intent == null) return
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return
        // Handled once, so a rotation or relaunch does not import it again.
        intent.action = null
        val file = read(uri) ?: return
        if (dartReady) {
            channel?.invokeMethod("opened", file)
        } else {
            queued.add(file)
        }
    }

    private fun read(uri: Uri): Map<String, Any>? {
        return try {
            val size = contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else -1L } ?: -1L
            if (size > MAX_BYTES) return null
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > MAX_BYTES) return null
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            } ?: return null
            mapOf("name" to name(uri), "bytes" to bytes)
        } catch (e: Exception) {
            null
        }
    }

    private fun name(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
        }
        return uri.lastPathSegment ?: "board.sortle"
    }

    companion object {
        private const val MAX_BYTES = 1024L * 1024L * 1024L
    }
}
