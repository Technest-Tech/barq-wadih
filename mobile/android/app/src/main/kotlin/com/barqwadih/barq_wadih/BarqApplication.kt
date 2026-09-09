package com.barqwadih.barq_wadih

import android.app.Application
import com.tiktok.TikTokBusinessSdk

class BarqApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        if (
            BuildConfig.TIKTOK_BUSINESS_APP_ID.isBlank() ||
                BuildConfig.TIKTOK_APP_ID.isBlank() ||
                BuildConfig.TIKTOK_APP_SECRET.isBlank()
        ) {
            return
        }

        val config = TikTokBusinessSdk.TTConfig(
            this,
            BuildConfig.TIKTOK_APP_SECRET,
        )
            .setAppId(BuildConfig.TIKTOK_BUSINESS_APP_ID)
            .setTTAppId(BuildConfig.TIKTOK_APP_ID)
            // Payments in Barq Wadih are confirmed outside Google Play. They
            // are tracked explicitly only after the backend confirms them.
            .disableAutoIapTrack()
            // Avoid broad automatic UI postbacks; explicit business events
            // are easier to audit and keep consistent with Snapchat CAPI.
            .disableAutoEnhancedDataPostbackEvent()
            .setLogLevel(
                if (BuildConfig.DEBUG) {
                    TikTokBusinessSdk.LogLevel.INFO
                } else {
                    TikTokBusinessSdk.LogLevel.NONE
                },
            )

        TikTokBusinessSdk.initializeSdk(config)
    }
}
