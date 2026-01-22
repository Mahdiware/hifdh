plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must be last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mahdiware.hifdh"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.mahdiware.hifdh"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Force all APKs to have the exact same version code, ignoring ABI splits logic
    applicationVariants.all {
        outputs.forEach { output ->
            if (output is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                output.versionCodeOverride = flutter.versionCode
            }
        }
    }

    signingConfigs {
        create("release") {
            // Require environment variable KEYS
            val keystorePath = System.getenv("KEYSTORE_PATH")
            require(!keystorePath.isNullOrEmpty()) {
                "Environment variable KEYSTORE_PATH is not set!"
            }

            storeFile = file(keystorePath)
            storePassword = System.getenv("KEYSTORE_PASSWORD")
                ?: throw GradleException("Environment variable KEYSTORE_PASSWORD is not set!")
            keyAlias = System.getenv("KEY_ALIAS")
                ?: throw GradleException("Environment variable KEY_ALIAS is not set!")
            keyPassword = System.getenv("KEY_PASSWORD")
                ?: throw GradleException("Environment variable KEY_PASSWORD is not set!")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false

            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
