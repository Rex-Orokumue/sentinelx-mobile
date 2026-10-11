package ng.com.sentinelxesports.app

import android.content.Intent
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sentinelx/share").setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val text = call.argument<String>("text")
            if (text.isNullOrBlank()) {
                result.error("invalid_text", "Nothing to share", null)
                return@setMethodCallHandler
            }
            try {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(intent, null))
                result.success(null)
            } catch (error: Exception) {
                result.error("share_failed", error.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sentinelx/referrals").setMethodCallHandler { call, result ->
            if (call.method != "readInstallReferrer") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val client = InstallReferrerClient.newBuilder(applicationContext).build()
            val finished = AtomicBoolean(false)
            try {
                client.startConnection(object : InstallReferrerStateListener {
                    override fun onInstallReferrerSetupFinished(responseCode: Int) {
                        if (!finished.compareAndSet(false, true)) return
                        try {
                            when (responseCode) {
                                InstallReferrerClient.InstallReferrerResponse.OK -> result.success(client.installReferrer.installReferrer)
                                InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> result.success(null)
                                else -> result.error("referrer_unavailable", "Play Install Referrer unavailable", null)
                            }
                        } catch (error: Exception) {
                            result.error("referrer_failed", error.message, null)
                        } finally {
                            client.endConnection()
                        }
                    }

                    override fun onInstallReferrerServiceDisconnected() {
                        if (finished.compareAndSet(false, true)) {
                            client.endConnection()
                            result.error("referrer_disconnected", "Play Install Referrer disconnected", null)
                        }
                    }
                })
            } catch (error: Exception) {
                if (finished.compareAndSet(false, true)) result.error("referrer_failed", error.message, null)
                client.endConnection()
            }
        }
    }
}
