package com.awm.aiwithme

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.awm.aiwithme/llama_method"
    private val EVENT_CHANNEL = "com.awm.aiwithme/llama_event"

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initModel" -> {
                    val modelPath = call.argument<String>("modelPath") ?: ""
                    val nCtx = call.argument<Int>("nCtx") ?: 1024
                    val nThreads = call.argument<Int>("nThreads") ?: 4

                    executor.execute {
                        val success = LlamaBridge.nativeInitModel(modelPath, nCtx, nThreads)
                        mainHandler.post {
                            result.success(success)
                        }
                    }
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt") ?: ""
                    executor.execute {
                        LlamaBridge.nativeGenerate(prompt, object : LlamaBridge.LlamaCallback {
                            override fun onTokenBytes(bytes: ByteArray) {
                                val tokenStr = String(bytes, Charsets.UTF_8)
                                mainHandler.post {
                                    eventSink?.success(mapOf("type" to "token", "content" to tokenStr))
                                }
                            }

                            override fun onGenerationComplete() {
                                mainHandler.post {
                                    eventSink?.success(mapOf("type" to "done"))
                                }
                            }
                        })
                    }
                    result.success(true)
                }
                "stopGeneration" -> {
                    LlamaBridge.nativeStopGeneration()
                    result.success(true)
                }
                "freeModel" -> {
                    executor.execute {
                        LlamaBridge.nativeFreeModel()
                        mainHandler.post {
                            result.success(true)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.execute {
            LlamaBridge.nativeFreeModel()
        }
        executor.shutdown()
    }
}
