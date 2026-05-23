# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Safe default rules for common Flutter plugins (Geolocator, Image Picker, WebView, etc.)
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Keep multi-dex classes
-keep class androidx.multidex.** { *; }

# Don't warn for common libraries
-dontwarn android.webkit.**
-dontwarn javax.annotation.**
-dontwarn com.google.android.play.core.**

