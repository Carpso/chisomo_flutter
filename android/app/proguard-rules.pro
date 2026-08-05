# Kingdom Sponsor release ProGuard/R8 rules.
# R8 full mode is enabled via android.enableR8.fullMode=true in gradle.properties.

# Keep line numbers for readable stack traces (Sentry).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Firebase Messaging / google-services generated classes.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter engine + plugins (kept by the Flutter Gradle plugin; explicit fallback).
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep entry points that are reached via reflection.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
