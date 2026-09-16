package com.engram.engram

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Share target: "Share -> Engram" from another app.
 *
 * Written by hand rather than taken as a plugin: it comes to about thirty
 * lines.
 * There are two delivery routes and both are needed:
 *  - If the app **was opened by a share**, the intent arrives before the Dart
 *    side is ready; it waits in [pending] and Dart takes it with `takeInitialShare`.
 *  - If the app is **already open**, `onNewIntent` fires (launchMode singleTop)
 *    and the share is sent straight over the channel.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

    /** A share waiting until the Dart side is ready. */
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeInitialShare" -> {
                        result.success(pending)
                        // Single use: without clearing it, the app would replay
                        // the same share on every launch.
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

        handleShare(intent, deliverNow = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShare(intent, deliverNow = true)
    }

    private fun handleShare(intent: Intent?, deliverNow: Boolean) {
        val text = extractSharedText(intent) ?: return

        // Consume the intent: reprocessing the same one (if the activity is
        // recreated) would turn the share into a second card.
        intent?.removeExtra(Intent.EXTRA_TEXT)
        intent?.removeExtra(Intent.EXTRA_SUBJECT)

        val ch = channel
        if (deliverNow && ch != null) ch.invokeMethod("onShare", text) else pending = text
    }

    /**
     * Extracts the shared text.
     *
     * The title and the link arrive in separate fields: sharing a web page puts
     * the page title in `EXTRA_SUBJECT` and the address in `EXTRA_TEXT`. Together
     * they make a far better card face than the address alone -- which is why
     * they are joined on consecutive lines.
     */
    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null

        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim()
        val body = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()

        return listOfNotNull(
            subject?.takeIf { it.isNotEmpty() },
            // Some apps send the title as both the subject and the body; there
            // is no point writing the same text twice.
            body?.takeIf { it.isNotEmpty() && it != subject },
        ).joinToString("\n").takeIf { it.isNotEmpty() }
    }

    private companion object {
        const val CHANNEL = "com.engram.engram/share"
    }
}
