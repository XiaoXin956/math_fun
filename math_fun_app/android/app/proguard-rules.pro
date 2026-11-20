# Flutter 引擎与插件通过 JNI / 反射加载，保留入口及插件注册类
-keep class com.example.math_fun_app.MainActivity { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# native 方法不能被重命名，否则 JNI 找不到符号
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留注解，部分插件依赖运行时注解
-keepattributes *Annotation*

# 抑制 Flutter/插件中常见的可选依赖告警，避免打包失败
-dontwarn io.flutter.**
-dontwarn kotlin.**
