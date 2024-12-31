# Flutter 관련 기본 규칙
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# 예시로 필요한 다른 라이브러리 및 클래스 보존
-keep class com.google.** { *; }
-dontwarn com.google.**
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy