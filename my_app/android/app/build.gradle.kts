plugins {
    id("com.android.application")
    id("kotlin-android")
    // Ang Flutter Gradle Plugin ay dapat laging huli sa listahang ito.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Siguraduhing tugma ito sa package name mo sa pubspec.yaml
    namespace = "com.example.my_app"

    // In-set sa 36 para sa compatibility ng google_sign_in at iba pang plugins
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Ginawang Java 17 para sa modernong Gradle at Android SDK 36
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Direct string na "17" para iwas sa error sa compilation
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.my_app"

        // MinSdk 21 ay standard para sa karamihan ng devices ngayon
        minSdk = 21

        // Dapat laging match sa compileSdk
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug keys muna para hindi mag-error sa signing habang nag-e-experiment
            signingConfig = signingConfigs.getByName("debug")

            // Naka-false muna para iwas sa AAPT2 compilation errors sa resources
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}