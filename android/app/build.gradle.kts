import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release (A-04): lê android/key.properties, que fica fora do git.
// Chaves esperadas: storeFile, storePassword, keyAlias, keyPassword (ver README).
val keystorePropertiesFile = rootProject.file("key.properties")
val temKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (temKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun propriedadeDoKeystore(nome: String): String =
    requireNotNull(keystoreProperties.getProperty(nome)) { "android/key.properties sem a chave '$nome'." }

android {
    namespace = "com.unirv.betfriends"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.unirv.betfriends"
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

    signingConfigs {
        if (temKeystore) {
            create("release") {
                keyAlias = propriedadeDoKeystore("keyAlias")
                keyPassword = propriedadeDoKeystore("keyPassword")
                storeFile = file(propriedadeDoKeystore("storeFile"))
                storePassword = propriedadeDoKeystore("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Sem key.properties (ambiente de desenvolvimento) cai na chave de debug
            // para `flutter run --release` funcionar; esse artefato não é publicável.
            signingConfig = if (temKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties ausente: release assinado com a chave de debug.")
                signingConfigs.getByName("debug")
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
