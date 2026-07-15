# JNA — uses reflection to access native peer fields
-keep class com.sun.jna.** { *; }
-keepclassmembers class * {
    @com.sun.jna.* *;
}
# JNA references java.awt.* which doesn't exist on Android
-dontwarn java.awt.Component
-dontwarn java.awt.GraphicsEnvironment
-dontwarn java.awt.HeadlessException
-dontwarn java.awt.Window

# BitBox02 bridge (gomobile) — from bitboxbridge.aar proguard.txt
-keep class go.** { *; }
-keep class bridge.** { *; }

# App package
-keep class onl.coconut.wallet.** { *; }
