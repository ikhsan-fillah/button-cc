# Setting Android & iOS

Dokumen ini merangkum konfigurasi native yang perlu diperhatikan untuk aplikasi Buzzer Cerdas Cermat.

## Android

| File | Yang perlu diperhatikan |
| --- | --- |
| `android/app/build.gradle.kts` | `applicationId` dan `namespace` diset ke `com.kkn.cerdascermatbuzzer`; ganti ke package final sebelum publish jika diperlukan. `minSdk` mengikuti `flutter.minSdkVersion` yang efektifnya `23` pada toolchain project ini. `signingConfig` release masih memakai debug dan wajib diganti ke keystore asli sebelum rilis. |
| `android/app/src/main/AndroidManifest.xml` | Permission `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, dan `ACCESS_LOCAL_NETWORK` sudah didaftarkan. |
| `android/app/src/main/kotlin/com/example/button_cc/MainActivity.kt` | Method channel `cerdas_cermat_buzzer/permissions` sudah menangani request runtime permission `ACCESS_LOCAL_NETWORK` untuk Android 16+ (`SDK_INT >= 36`). |
| `android/local.properties` | Otomatis dibuat Android Studio atau Flutter untuk path SDK/Flutter. Jangan commit ke git. |
| `android/app/src/main/res/mipmap-*` | Icon app masih default Flutter. Generate ulang jika ingin icon custom. |

## iOS

> Konfigurasi iOS final wajib dilakukan di macOS/Xcode.

| File | Yang perlu diperhatikan |
| --- | --- |
| `ios/Runner/Info.plist` | `NSLocalNetworkUsageDescription` dan `NSBonjourServices` sudah didaftarkan untuk akses jaringan lokal/socket. |
| `ios/Podfile` | Minimum platform diset ke `platform :ios, '13.0'`. Jalankan `pod install` dari folder `ios/` setelah `flutter pub get` di macOS. |
| Xcode Signing & Capabilities | Atur langsung lewat Xcode: pilih Apple Developer Team dan Bundle Identifier unik. |
| `ios/Runner/Assets.xcassets` | Icon app dan launch image masih default Flutter. Generate ulang jika ingin custom. |

## Catatan Rilis

- Android release build belum aman untuk publish sampai `signingConfig` diganti dari debug ke keystore release.
- Package name Android saat ini adalah `com.kkn.cerdascermatbuzzer`; pastikan konsisten dengan kebutuhan Play Store atau organisasi.
- Flutter versi project ini membutuhkan minimum Android SDK 23. Jika memaksa `minSdk 21`, Gradle gagal di task `:app:DebugMinSdkCheck`.
- iOS bundle identifier masih mengikuti setting Xcode `$(PRODUCT_BUNDLE_IDENTIFIER)` dan perlu diset di Xcode.
