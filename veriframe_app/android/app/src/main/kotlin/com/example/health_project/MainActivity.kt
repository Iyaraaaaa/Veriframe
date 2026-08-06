package com.example.health_project

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.veriframe_app/share_pdf"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sharePdfToApp" -> {
                        val filePath = call.argument<String>("filePath")
                        val appPackage = call.argument<String>("appPackage")
                        val recipient = call.argument<String>("recipient")
                        val subject = call.argument<String>("subject")
                        if (filePath == null || appPackage == null) {
                            result.error("INVALID_ARGS", "filePath and appPackage are required", null)
                            return@setMethodCallHandler
                        }
                        sharePdfToApp(filePath, appPackage, recipient, subject)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sharePdfToApp(
        filePath: String,
        appPackage: String,
        recipient: String?,
        subject: String?
    ) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                return
            }

            val authority = "${applicationContext.packageName}.fileprovider"
            val contentUri: Uri = FileProvider.getUriForFile(
                applicationContext,
                authority,
                file
            )

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, contentUri)
                setPackage(appPackage)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

                subject?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
            }

            if (recipient != null) {
                if (appPackage == "com.whatsapp") {
                    intent.putExtra("jid", "${recipient}@s.whatsapp.net")
                } else {
                    intent.putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                }
            }

            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}