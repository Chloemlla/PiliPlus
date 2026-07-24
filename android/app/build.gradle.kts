import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import org.jetbrains.kotlin.konan.properties.Properties

plugins {
    id("com.android.application")
    id("androidx.baselineprofile")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpMajorVersion >= 9 &&
        (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
if (!isBuiltInKotlinEnabled) {
    apply(plugin = "org.jetbrains.kotlin.android")
}
val targetAndroidSdk = rootProject.extra["targetAndroidSdk"] as Int

android {
    namespace = "com.chloemlla.piliplus"
    compileSdk = targetAndroidSdk
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.chloemlla.piliplus"
        // lumen-crash requires minSdk 26.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = targetAndroidSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions.jniLibs.useLegacyPackaging = true

    val keyProperties = Properties().also {
        val properties = rootProject.file("key.properties")
        if (properties.exists())
            it.load(properties.inputStream())
    }

    val config = keyProperties.getProperty("storeFile")?.let {
        signingConfigs.create("release") {
            storeFile = file(it)
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    buildFeatures {
        if (project.hasProperty("dev")) {
            resValues = true
        }
    }

    buildTypes {
        all {
            signingConfig = config ?: signingConfigs["debug"]
        }
        release {
            if (project.hasProperty("dev")) {
                applicationIdSuffix = ".dev"
                resValue(
                    type = "string",
                    name = "app_name",
                    value = "PiliPlus dev",
                )
            }
            // Flutter release enables minify/R8 by default; keep Scan Kit / optional
            // HMS network stubs from failing full-mode missing-class checks.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.forEach { output ->
            (output as ApkVariantOutputImpl).versionCodeOverride = flutter.versionCode
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
    val lumenCrashVersion =
        providers.gradleProperty("lumenCrashVersion")
            .orElse(providers.environmentVariable("LUMEN_CRASH_VERSION"))
            .orElse("0.1.0")
            .get()

    // Huawei Scan Kit full SDK (scanplus): camera + bitmap decode without GMS.
    // Independent SDK path — no agconnect-services.json / AGConnect plugin required.
    // Artifact lives on https://developer.huawei.com/repo/ (see android/build.gradle.kts).
    implementation("com.huawei.hms:scanplus:2.15.0.301")
    implementation("com.tencent:mmkv-static:1.3.14")
    // Capture-only host: Flutter owns crash product UI. Prefer lumen-crash-core
    // so Compose crash UI / FileProvider share surface is not pulled in.
    implementation("com.chloemlla.lumen:lumen-crash-core:$lumenCrashVersion")
}

baselineProfile {
    mergeIntoMain = true
    saveInSrc = true
    automaticGenerationDuringBuild = false
}

dependencies {
    implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    baselineProfile(project(":baselineprofile"))
}
