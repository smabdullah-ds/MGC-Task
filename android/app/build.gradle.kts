import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase is optional: the build works without google-services.json and the
// app then runs with fake analytics/remote config (see README → Firebase).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

// Secrets that must never be committed live in android/key.properties
// (git-ignored) or environment variables. Defaults are Google's test IDs.
val secrets = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun secret(name: String, default: String = ""): String =
    secrets.getProperty(name) ?: System.getenv(name) ?: default

android {
    namespace = "com.bazaarsort.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.bazaarsort.game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] =
            secret("ADMOB_APP_ID_ANDROID", "ca-app-pub-3940256099942544~3347511713")
    }

    // Upload key from android/key.properties (git-ignored; see RELEASE.md):
    //   storeFile=../upload-keystore.jks  storePassword=…  keyAlias=upload  keyPassword=…
    // Without it, release builds fall back to the debug key so local
    // `flutter run --release` still works — Play Console rejects those.
    val hasUploadKey = secret("storeFile").isNotEmpty()
    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(secret("storeFile"))
                storePassword = secret("storePassword")
                keyAlias = secret("keyAlias")
                keyPassword = secret("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasUploadKey) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
