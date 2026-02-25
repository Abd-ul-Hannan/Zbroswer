package com.example.zbrowser

import android.app.SearchManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.speech.RecognizerResultsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    private var url: String? = null
    private val CHANNEL = "com.pichillilorenzo.flutter_browser.intent_data"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val action = intent.action
        if (RecognizerResultsIntent.ACTION_VOICE_SEARCH_RESULTS == action) {
            return
        }
        if (Intent.ACTION_VIEW == action) {
            val data: Uri? = intent.data
            if (data != null) url = data.toString()
        } else if (Intent.ACTION_SEARCH == action || MediaStore.INTENT_ACTION_MEDIA_SEARCH == action
            || Intent.ACTION_WEB_SEARCH == action
        ) {
            url = intent.getStringExtra(SearchManager.QUERY)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method == "getIntentData") {
                    result.success(url ?: "") // Ensure it never returns null
                    this.url = null
                } else {
                    result.notImplemented()
                }
            }
    }
}
