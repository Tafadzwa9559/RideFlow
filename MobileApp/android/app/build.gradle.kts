plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val hasReleaseSigning = run {
    val required = listOf("TRIVIA_KEYSTORE", "TRIVIA_STORE_PASSWORD", "TRIVIA_KEY_ALIAS", "TRIVIA_KEY_PASSWORD")
    val present = required.all { !System.getenv(it).isNullOrBlank() }
    if (!present) {
        false
    } else {
        val keystorePath = System.getenv("TRIVIA_KEYSTORE")
        !keystorePath.isNullOrBlank() && file(keystorePath).isFile
    }
}

android {
    namespace = "com.mordecsolutions.rideflow_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mordecsolutions.trivia"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("production") {
            val storePath = System.getenv("TRIVIA_KEYSTORE")
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
                storePassword = System.getenv("TRIVIA_STORE_PASSWORD")
                keyAlias = System.getenv("TRIVIA_KEY_ALIAS")
                keyPassword = System.getenv("TRIVIA_KEY_PASSWORD")
            }
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("production")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                logger.lifecycle("WARNING: Release signing credentials missing; using debug keystore for local APK build.")
            }
        }
    }
}

// Require a real production keystore only when the release-signing env vars are explicitly configured.
// Otherwise allow a local debug keystore so developers can still assemble a build for testing.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        val required = listOf("TRIVIA_KEYSTORE", "TRIVIA_STORE_PASSWORD", "TRIVIA_KEY_ALIAS", "TRIVIA_KEY_PASSWORD")
        val configured = required.filter { !System.getenv(it).isNullOrBlank() }
        if (configured.isNotEmpty() && configured.size != required.size) {
            val missing = required.filter { System.getenv(it).isNullOrBlank() }
            check(missing.isEmpty()) {
                "Release signing credentials missing: ${missing.joinToString()}. Supply the existing Trivia release key securely; unsigned release APKs are not installable. See README.md."
            }
        }
        if (hasReleaseSigning) {
            check(file(System.getenv("TRIVIA_KEYSTORE")).isFile) {
                "TRIVIA_KEYSTORE must reference an existing release keystore file."
            }
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
