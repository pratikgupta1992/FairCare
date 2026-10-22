plugins {
    id("com.android.application")
    // FlutterFire: reads android/app/google-services.json (dropped
    // in by `flutterfire configure` — intentionally NOT in the
    // repo yet; an Android build will fail until that file exists,
    // while analyze/test are unaffected).
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.faircare.faircare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.faircare.faircare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Minification MUST stay off for this app: shared_preferences_android
            // resolves its Kotlin API from Dart via JNI using literal JVM
            // signatures (e.g. SharedPreferencesApiRegistrar.getAll(String,
            // List, kotlin.coroutines.Continuation)). Flutter's release build
            // runs R8 by default, which renamed kotlin.coroutines.Continuation
            // and broke that lookup (NoSuchMethodError on first prefs read,
            // 2026-10-21). Sideloaded personal app: correctness over size.
            isMinifyEnabled = false
            isShrinkResources = false
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
