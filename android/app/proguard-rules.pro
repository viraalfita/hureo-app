# Keep ML Kit, Play Services, TensorFlow Lite classes to avoid stripping
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
# Avoid warnings from ML Kit / Play Services
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
