# Firebase Messaging / Installations / IID
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter embedding and plugins (including firebase_messaging generated registrant)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugins.firebasemessaging.** { *; }
-keep class io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry { *; }

# Keep classes used reflectively by Flutter plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
# Shush the R8 warnings about Play Core (which Flutter references but we don't use)
-dontwarn com.google.android.play.core.**

# If you are using Firebase/FCM, add these to prevent them from being stripped
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Essential Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }