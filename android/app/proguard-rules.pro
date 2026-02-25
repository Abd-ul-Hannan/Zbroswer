# WebView compatibility rules
-dontwarn android.app.UiModeManager$ContrastChangeListener
-dontwarn android.webkit.WebViewRenderProcessClient
-dontwarn androidx.webkit.internal.WebViewRenderProcessClientFrameworkAdapter

# Keep WebView classes
-keep class android.webkit.** { *; }
-keep class androidx.webkit.** { *; }

# Keep flutter_inappwebview classes
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# Suppress warnings for missing classes
-dontwarn android.app.UiModeManager
-dontwarn android.webkit.WebViewRenderProcessClient