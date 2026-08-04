import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// 릴리즈 서명 설정 (key.properties 파일에서 읽기)
// 실제 파일은 gitignore 대상이며 release task에서만 필수다.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
fun releaseProperty(name: String): String? =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val releaseKeyAlias = releaseProperty("keyAlias")
val releaseKeyPassword = releaseProperty("keyPassword")
val releaseStorePassword = releaseProperty("storePassword")
val releaseStorePath = releaseProperty("storeFile")
val releaseStoreFile = releaseStorePath?.let(::file)
val releaseSigningReady = keystorePropertiesFile.exists() &&
    releaseKeyAlias != null &&
    releaseKeyPassword != null &&
    releaseStorePassword != null &&
    releaseStoreFile?.isFile == true

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

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
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

// Release task가 요청된 경우에만 signing 자산을 검증한다. IDE sync와
// assembleDebug/profile/test는 signing 자산 없이도 정상 동작해야 한다.
gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.project == project && task.name.contains("release", ignoreCase = true)
    }
    if (releaseTaskRequested && !releaseSigningReady) {
        throw GradleException(
            "PetSpace release signing is not configured. " +
                "Provide a complete ignored android/key.properties and keystore."
        )
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
