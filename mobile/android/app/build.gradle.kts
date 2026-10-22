plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kounadia.kounadia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Clé de signature fixe (fournie par GitHub Actions) : les mises à jour s'installent par-dessus.
    val releaseKs = System.getenv("KOUNADIA_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        create("release") {
            if (releaseKs != null) {
                storeFile = releaseKs
                storeType = "pkcs12"
                storePassword = System.getenv("KOUNADIA_KEY_PASS")
                keyAlias = "kounadia"
                keyPassword = System.getenv("KOUNADIA_KEY_PASS")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kounadia.kounadia"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (releaseKs != null) "release" else "debug")
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

dependencies {
    // FileProvider : donne la nouvelle version à l'installateur Android.
    implementation("androidx.core:core:1.13.1")
}
