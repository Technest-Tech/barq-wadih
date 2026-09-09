import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

val trackingPropertiesFile = rootProject.file("tracking.properties")
val trackingProperties = Properties()
if (trackingPropertiesFile.exists()) {
    trackingProperties.load(FileInputStream(trackingPropertiesFile))
}

fun buildConfigString(value: String): String =
    "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""

android {
    namespace = "com.barqwadih.barq_wadih"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.barqwadih.barq_wadih"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        buildConfigField(
            "String",
            "TIKTOK_BUSINESS_APP_ID",
            buildConfigString(
                trackingProperties.getProperty(
                    "tiktok.business_app_id",
                    applicationId,
                ),
            ),
        )
        buildConfigField(
            "String",
            "TIKTOK_APP_ID",
            buildConfigString(trackingProperties.getProperty("tiktok.app_id", "")),
        )
        buildConfigField(
            "String",
            "TIKTOK_APP_SECRET",
            buildConfigString(trackingProperties.getProperty("tiktok.app_secret", "")),
        )
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            if (keyPropertiesFile.exists()) {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = keyProperties["storeFile"]?.let { file(it as String) }
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Release signing via android/key.properties (keystore kept outside the repo).
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.github.tiktok:tiktok-business-android-sdk:1.7.0")
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("com.google.android.play:app-update:2.1.0")
}
