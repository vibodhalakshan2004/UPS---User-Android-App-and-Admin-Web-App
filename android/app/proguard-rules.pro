# Flutter & Firebase keep rules

# Keep Flutter's embedding and plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase Auth, Firestore, Storage models and annotations
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Kotlin coroutines and metadata
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**

# Keep JSON model classes (if using reflection/gson)
-keep class **.model.** { *; }

# Keep classes with fields used by reflection (adjust as needed)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Google Play Core SplitInstall classes used by Flutter deferred components
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Prevent R8 from treating Play Core as required when not packaged
-dontnote com.google.android.play.core.**
