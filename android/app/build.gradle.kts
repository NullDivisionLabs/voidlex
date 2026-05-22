import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing keys are read from android/key.properties when present.
// The file is gitignored; see android/key.properties.example for the schema.
// Release packaging fails fast without a real key unless the developer passes
// `-PallowDebugReleaseSigning=true` for a local smoke build.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile")?.let {
    rootProject.file(it).exists()
} ?: false
val allowDebugReleaseSigning = (project.findProperty("allowDebugReleaseSigning") as? String)
    ?.equals("true", ignoreCase = true) == true
val shippedAbis = listOf("arm64-v8a", "x86_64")

android {
    namespace = "com.voidtunnel.voidtunnel"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.voidtunnel.voidtunnel"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Xray is shipped only for 64-bit Android ABIs. Keeping this filter
        // here prevents accidental universal APK/AAB outputs that install on
        // 32-bit ARM and then fail when XrayRuntime resolves libxray.so.
        //
        // Skipped when Flutter runs `flutter build apk --split-per-abi`: that
        // mode injects `splits.abi` with a single ABI per Gradle invocation,
        // and AGP refuses to combine `splits.abi` with an `ndk.abiFilters` set
        // covering a different ABI set. In split mode the splits mechanism
        // already enforces the per-APK ABI, so this safety net is redundant.
        val splitPerAbi = (project.findProperty("split-per-abi") as? String)
            ?.equals("true", ignoreCase = true) == true
        if (!splitPerAbi) {
            ndk {
                abiFilters += shippedAbis
            }
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // AGP requires a signing config during configuration. The
                // task-graph guard below blocks publishable release tasks
                // unless `-PallowDebugReleaseSigning=true` is explicit.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ABI policy: only arm64-v8a and x86_64 are shipped. There is no bundled
    // 32-bit Android Xray core, and supporting legacy armv7 devices would mean
    // owning a separate native build/provenance/test path. The Flutter
    // `target-platform` project property narrows Flutter's own ABI set, while
    // the package-level exclude below strips any armv7 native libraries that a
    // transitive Android dependency still contributes.

    packaging {
        jniLibs {
            // Xray is a standalone PIE executable, not a regular shared
            // library — XrayRuntime resolves it via ProcessBuilder against
            // nativeLibraryDir/libxray.so. That path only contains a real
            // file on disk when the OS extracts the .so out of the APK at
            // install time, which only happens when useLegacyPackaging is
            // `true` (equivalent to android:extractNativeLibs="true" in
            // the manifest).
            //
            // Flipping to `false` would shave ~36 MB off /data/app's
            // on-disk footprint (no extracted copy alongside the APK), but
            // would also leave `nativeLibraryDir/libxray.so` non-existent
            // and break exec. The alternative — manually copying the
            // binary out of assets into filesDir on first launch — adds
            // ~36 MB of one-shot I/O to cold start and loses the
            // OS-managed "exec-from-system-managed-dir" guarantee. Not
            // worth the trade-off for this app.
            useLegacyPackaging = true
            keepDebugSymbols += "**/libxray.so"
            excludes += "lib/armeabi-v7a/**"
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    // Slim build: pass `-PslimGeoData=true` to flutter/gradle to drop the
    // ~28 MB of bundled geoip.dat / geosite.dat from the APK. Users will
    // be prompted to download them on first VPN start via the existing
    // GeoData settings screen (GeoDataManager.download).
    val slimGeoData = (project.findProperty("slimGeoData") as? String)
        ?.equals("true", ignoreCase = true) == true
    if (slimGeoData) {
        androidResources {
            // Colon-separated globs; matches anywhere in the assets tree, so
            // both src/main/assets/xray/geoip.dat and any future relocations
            // are caught.
            ignoreAssetsPattern = "geoip.dat:geosite.dat"
        }
        logger.lifecycle("slimGeoData enabled: geoip.dat / geosite.dat will be excluded from APK assets")
    }
}

gradle.taskGraph.whenReady {
    val isReleasePackageTask = allTasks.any { task ->
        task.path == ":app:assembleRelease" ||
            task.path == ":app:bundleRelease" ||
            task.path == ":app:packageRelease" ||
            task.path == ":app:validateSigningRelease"
    }
    if (isReleasePackageTask && !hasReleaseKeystore && !allowDebugReleaseSigning) {
        throw org.gradle.api.GradleException(
            "Release signing key is not configured. Copy android/key.properties.example " +
                "to android/key.properties and set storeFile/keyAlias/passwords, or pass " +
                "-PallowDebugReleaseSigning=true for a local smoke build only."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Use sing-box/libbox only as the Android TUN engine. Xray remains the proxy core.
    implementation(files("libs/libbox.aar"))

    // Coroutines for async service lifecycle
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    // lifecycleScope on FlutterActivity so background work is cancelled when
    // the activity goes away instead of leaking via raw Thread {}.
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")

    // EncryptedSharedPreferences for the custom proxy auth password (#8 in the
    // hardening plan). Keyed via Android KeyStore.
    implementation("androidx.security:security-crypto:1.1.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
