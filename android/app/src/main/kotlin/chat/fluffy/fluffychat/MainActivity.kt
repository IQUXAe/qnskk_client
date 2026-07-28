package chat.fluffy.fluffychat

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return provideEngine(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }

    companion object {
        private const val CHANNEL = "org.iquxae.qnskk/installer"
        var engine: FlutterEngine? = null

        fun provideEngine(context: Context): FlutterEngine {
            val isNew = engine == null
            val eng = engine ?: FlutterEngine(context, emptyArray(), true, false)
            if (isNew) {
                engine = eng
                setupInstallerChannel(eng, context)
            }
            return eng
        }

        private fun setupInstallerChannel(flutterEngine: FlutterEngine, context: Context) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "APK file does not exist at $filePath", null)
                                return@setMethodCallHandler
                            }
                            val intent = Intent(Intent.ACTION_VIEW)
                            val apkUri = FileProvider.getUriForFile(
                                context,
                                "${context.packageName}.fileprovider",
                                file
                            )
                            intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        }
    }
}
