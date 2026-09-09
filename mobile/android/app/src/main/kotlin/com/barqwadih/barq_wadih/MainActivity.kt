package com.barqwadih.barq_wadih

import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability
import com.tiktok.TikTokBusinessSdk
import com.tiktok.appevents.base.TTBaseEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

// FlutterFragmentActivity (not FlutterActivity) is required by the local_auth
// plugin to host the native biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val TRACKING_CHANNEL = "com.barqwadih.app/marketing_tracking"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRACKING_CHANNEL,
        ).setMethodCallHandler(::handleTrackingCall)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.barqwadih.app/app_update",
        ).setMethodCallHandler { call, result ->
            if (call.method != "installedInfo") {
                result.notImplemented()
            } else {
                checkPublishedUpdate(result)
            }
        }
    }

    private fun checkPublishedUpdate(result: MethodChannel.Result) {
        try {
            val installed = packageManager.getPackageInfo(packageName, 0)
            val installedCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                installed.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                installed.versionCode.toLong()
            }
            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
            val base = mapOf(
                "platform" to "android", "bundleId" to packageName,
                "version" to installed.versionName.orEmpty(),
                "buildNumber" to installedCode, "sdkVersion" to Build.VERSION.SDK_INT,
                "storeInstalled" to (installer == "com.android.vending" && !BuildConfig.DEBUG),
                "playAvailabilityKnown" to false,
            )
            val updateTask = AppUpdateManagerFactory.create(applicationContext).appUpdateInfo
            val handler = Handler(Looper.getMainLooper())
            var replied = false
            val timeout = Runnable {
                if (!replied) { replied = true; result.success(base) }
            }
            handler.postDelayed(timeout, 7000)
            updateTask
                .addOnSuccessListener { info ->
                    if (replied) return@addOnSuccessListener
                    replied = true
                    handler.removeCallbacks(timeout)
                    result.success(base + mapOf(
                        "playAvailabilityKnown" to true,
                        "availableBuildNumber" to info.availableVersionCode(),
                        "updateAvailable" to
                            (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
                    ))
                }
                .addOnFailureListener {
                    if (replied) return@addOnFailureListener
                    replied = true
                    handler.removeCallbacks(timeout)
                    result.success(base)
                }
        } catch (_: Exception) {
            result.success(null)
        }
    }

    private fun handleTrackingCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "trackTikTokEvent" -> {
                    val name = call.argument<String>("name").orEmpty()
                    if (name.isBlank()) {
                        result.error("invalid_event", "Event name is required.", null)
                        return
                    }

                    val eventId = call.argument<String>("eventId")
                    val builder = if (eventId.isNullOrBlank()) {
                        TTBaseEvent.newBuilder(name)
                    } else {
                        TTBaseEvent.newBuilder(name, eventId)
                    }
                    @Suppress("UNCHECKED_CAST")
                    val properties =
                        call.argument<Map<String, Any?>>("properties") ?: emptyMap()
                    properties.forEach { (key, value) ->
                        if (value != null) builder.addProperty(key, value)
                    }
                    TikTokBusinessSdk.trackTTEvent(builder.build())
                    result.success(null)
                }

                "identifyTikTokUser" -> {
                    TikTokBusinessSdk.logout()
                    TikTokBusinessSdk.identify(
                        call.argument<String>("externalId").orEmpty(),
                        call.argument<String>("username"),
                        call.argument<String>("phone"),
                        call.argument<String>("email"),
                    )
                    result.success(null)
                }

                "logoutTikTokUser" -> {
                    TikTokBusinessSdk.logout()
                    result.success(null)
                }

                "requestTrackingAuthorization" -> result.success(true)
                "getSnapAppData" -> result.success(buildSnapAppData())
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error("tracking_error", error.message, null)
        }
    }

    private fun buildSnapAppData(): Map<String, Any> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
        val metrics = resources.displayMetrics
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            resources.configuration.locale
        }
        val dataDirectory = Environment.getDataDirectory()
        val bytesPerGb = 1024L * 1024L * 1024L

        return mapOf(
            "app_id" to packageName,
            "advertiser_tracking_enabled" to true,
            "extinfo" to listOf(
                "a2",
                packageName,
                packageInfo.versionName.orEmpty(),
                versionCode.toString(),
                Build.VERSION.RELEASE.orEmpty(),
                Build.MODEL.orEmpty(),
                locale.toLanguageTag(),
                TimeZone.getDefault().getDisplayName(false, TimeZone.SHORT, Locale.US),
                "",
                metrics.widthPixels,
                metrics.heightPixels,
                metrics.density.toString(),
                Runtime.getRuntime().availableProcessors(),
                dataDirectory.totalSpace / bytesPerGb,
                dataDirectory.freeSpace / bytesPerGb,
                TimeZone.getDefault().id,
            ),
        )
    }
}
