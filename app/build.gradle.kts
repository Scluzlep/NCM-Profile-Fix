plugins {
    id("com.android.application")
}

android {
    namespace = "com.scluzlep.ncmprofilefix"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.scluzlep.ncmprofilefix"
        minSdk = 26
        targetSdk = 28
        versionCode = 1
        versionName = "0.1.0"
    }

    signingConfigs {
        create("ciRelease") {
            val path = System.getenv("NCM_KEYSTORE_FILE")
            if (!path.isNullOrBlank()) {
                storeFile = file(path)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = false
            if (!System.getenv("NCM_KEYSTORE_FILE").isNullOrBlank()) {
                signingConfig = signingConfigs.getByName("ciRelease")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources {
            merges += "META-INF/xposed/*"
        }
    }
}

dependencies {
    // Framework supplies API classes at runtime.
    compileOnly("io.github.libxposed:api:102.0.0")
}
