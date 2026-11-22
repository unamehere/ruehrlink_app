package de.ruehrlink.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Empfängt Rezept-Dateien (.rlrezept) über „Öffnen mit Rührlink“ (VIEW) und das Teilen-Menü (SEND)
 * und reicht Name + Inhalt an Flutter weiter (lib/features/rezepte/rezept_teilen.dart).
 *
 * Bewusst ein kleiner eigener Kanal statt eines Pakets: gelesen wird nur die eine Datei, die der
 * Nutzer übergibt, nichts geht nach außen. Flutter holt die Datei mit „pending“ ab; kommt eine
 * neue, während die App läuft, meldet „available“ das.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingUri: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Nach einem Neuaufbau der Activity bzw. aus dem Verlauf gestartet: nicht noch einmal anbieten.
        val fromHistory = (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (savedInstanceState == null && !fromHistory) pendingUri = uriOf(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method != "pending") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = pendingUri
                pendingUri = null
                if (uri == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                // Lesen nicht im UI-Thread (Datei kann einige MB groß sein).
                Thread {
                    val data = read(uri)
                    runOnUiThread { result.success(data) }
                }.start()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = uriOf(intent) ?: return
        pendingUri = uri
        channel?.invokeMethod("available", null)
    }

    private fun uriOf(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND ->
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        else -> null
    }

    private fun read(uri: Uri): Map<String, Any?> = try {
        val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("leer")
        val out = ByteArrayOutputStream()
        input.use {
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = it.read(buf)
                if (n < 0) break
                out.write(buf, 0, n)
                if (out.size() > MAX_BYTES) return mapOf("error" to "size")
            }
        }
        mapOf("name" to displayName(uri), "bytes" to out.toByteArray())
    } catch (e: Exception) {
        mapOf("error" to "read")
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst() && !it.isNull(0)) return it.getString(0)
            }
        } catch (e: Exception) {
            // kein Name – egal
        }
        return uri.lastPathSegment ?: ""
    }

    companion object {
        private const val CHANNEL = "de.ruehrlink.app/rezept_datei"

        /** Wie RezeptGrenzen.dateiBytes in der App. */
        private const val MAX_BYTES = 16 * 1024 * 1024
    }
}
