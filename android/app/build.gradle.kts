plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "co.mano.attendance"

    // SDK 36 required by plugins (camera, geolocator, etc.)
    compileSdk = 36
    // optional: ndkVersion = "21.4.7075529" // uncomment and set if you need a specific ndk

    defaultConfig {
        applicationId = "co.mano.attendance"
        minSdk = 24
        targetSdk = 35
        versionCode = 16
        versionName = "1.0.0"
        multiDexEnabled = true // Fixes "crash" due to method limit on older devices

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties["keyAlias"] != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.14.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    // Force compatible androidx.activity version to avoid AGP 8.9.1 requirement
    constraints {
        implementation("androidx.activity:activity:1.9.3") {
            because("androidx.activity 1.11.0 requires AGP 8.9.1 which is not stable yet")
        }
        implementation("androidx.activity:activity-ktx:1.9.3") {
            because("androidx.activity 1.11.0 requires AGP 8.9.1 which is not stable yet")
        }
    }
}
