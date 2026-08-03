import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.jena.petspace"
    compileSdk = 36                          // Play 요구사항: API 35+ (36으로 상향)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 릴리즈 서명 설정 (key.properties 파일에서 읽기)
    // 배포 전: android/ 폴더에 key.properties 파일 생성 필요
    // key.properties 파일 형식:
    //   storePassword=YOUR_KEYSTORE_PASSWORD
    //   keyPassword=YOUR_KEY_PASSWORD
    //   keyAlias=petspace
    //   storeFile=../petspace-release.jks
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }
    val requiredSigningProperties =
        listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    val hasAllSigningProperties = requiredSigningProperties.all { key ->
        (keystoreProperties[key] as String?)?.isNotBlank() == true
    }
    val configuredStoreFile =
        (keystoreProperties["storeFile"] as String?)?.let { file(it) }
    val releaseSigningReady =
        keystorePropertiesFile.exists() &&
            hasAllSigningProperties &&
            configuredStoreFile?.exists() == true
    val releaseBuildRequested = gradle.startParameter.taskNames.any { task ->
        task.contains("release", ignoreCase = true)
    }

    if (releaseBuildRequested && !releaseSigningReady) {
        throw GradleException(
            "Release signing is not configured. " +
                "Provide an ignored android/key.properties file and upload keystore.",
        )
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = configuredStoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.jena.petspace"
        minSdk = flutter.minSdkVersion                      // Android 5.0+ (Lollipop)
        targetSdk = 36                   // Android 16 (Play 요구사항: API 35+)
        versionCode = 4                  // Play 업로드용 — 1·2·3 이미 사용됨(재사용 불가)
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            // applicationIdSuffix 제거 — google-services.json과 패키지명 일치 필요
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.multidex:multidex:2.0.1")

    // Exclude deprecated firebase-iid to prevent conflicts with firebase-messaging
    configurations.all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}
