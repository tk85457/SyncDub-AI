package com.syncdub.livedub

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.MediaExtractor
import android.media.MediaCodec
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "com.syncdub.livedub/audio_routing"
    private val FLOATING_CHANNEL = "com.syncdub.livedub/floating_overlay"

    companion object {
        var overlayChannel: MethodChannel? = null

        // Set while an activity instance is alive. Lets the overlay/notification pause take effect in the
        // native audio layer IMMEDIATELY (input gate, playback flush, system volume back to 100%) instead
        // of waiting for the Flutter round trip overlay -> Dart -> native.
        @Volatile
        var pauseHintHandler: ((Boolean) -> Unit)? = null

        fun nativePauseHint(paused: Boolean) {
            try {
                pauseHintHandler?.invoke(paused)
            } catch (_: Exception) {}
        }

        fun triggerPauseResume() {
            overlayChannel?.invokeMethod("onPauseResumeToggled", null)
        }

        fun triggerOverlayClosed() {
            overlayChannel?.invokeMethod("onOverlayClosed", null)
        }

        fun triggerStopDubbing() {
            try {
                overlayChannel?.invokeMethod("onStopDubbingRequested", null)
            } catch (_: Exception) {}
        }

        fun triggerLanguageCycle() {
            overlayChannel?.invokeMethod("onLanguageCycleRequested", null)
        }

        fun triggerLanguageSelected(langCode: String) {
            overlayChannel?.invokeMethod("onLanguageSelectedFromOverlay", mapOf("code" to langCode))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Audio Routing MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager == null) {
                result.error("UNAVAILABLE", "AudioManager not available", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "getAudioDevices" -> {
                    try {
                        val deviceList = mutableListOf<Map<String, Any>>()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                            for (dev in devices) {
                                val typeStr = when (dev.type) {
                                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
                                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                                    AudioDeviceInfo.TYPE_USB_HEADSET,
                                    AudioDeviceInfo.TYPE_USB_DEVICE -> "headset"
                                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
                                    else -> {
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                            (dev.type == AudioDeviceInfo.TYPE_BLE_HEADSET || dev.type == AudioDeviceInfo.TYPE_BLE_SPEAKER)) {
                                            "bluetooth"
                                        } else {
                                            "other"
                                        }
                                    }
                                }

                                val name = if (dev.productName.isNotEmpty()) {
                                    dev.productName.toString()
                                } else {
                                    when (typeStr) {
                                        "speaker" -> "Phone Speaker"
                                        "earpiece" -> "Phone Earpiece"
                                        "headset" -> "Wired Headset"
                                        "bluetooth" -> "Bluetooth Audio"
                                        else -> "External Device"
                                    }
                                }

                                deviceList.add(mapOf(
                                    "id" to dev.id,
                                    "name" to name,
                                    "type" to typeStr
                                ))
                            }
                        }

                        // Ensure fallback speaker device is always present if list is empty
                        if (deviceList.isEmpty()) {
                            deviceList.add(mapOf(
                                "id" to 1,
                                "name" to "Phone Speaker",
                                "type" to "speaker"
                            ))
                        }

                        result.success(deviceList)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "setAudioDevice" -> {
                    try {
                        val deviceType = call.argument<String>("type") ?: "speaker"
                        if (deviceType == "speaker") {
                            audioManager.isSpeakerphoneOn = true
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                audioManager.clearCommunicationDevice()
                            }
                        } else {
                            audioManager.isSpeakerphoneOn = false
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val targetId = call.argument<Int>("id")
                                if (targetId != null) {
                                    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                                    val matched = devices.find { it.id == targetId }
                                    if (matched != null) {
                                        audioManager.setCommunicationDevice(matched)
                                    }
                                }
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Floating Overlay MethodChannel
        val floatingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_CHANNEL)
        overlayChannel = floatingChannel
        pauseHintHandler = pauseHint

        floatingChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "showOverlay" -> {
                    try {
                        val isTranslating = call.argument<Boolean>("isTranslating") ?: false
                        val isPaused = call.argument<Boolean>("isPaused") ?: false
                        val targetLang = call.argument<String>("targetLang") ?: "HI"
                        val targetLangFlag = call.argument<String>("targetLangFlag") ?: "🇮🇳"
                        val targetLangName = call.argument<String>("targetLangName") ?: "Hindi"
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = FloatingOverlayService.ACTION_SHOW
                            putExtra("isTranslating", isTranslating)
                            putExtra("isPaused", isPaused)
                            putExtra("targetLang", targetLang)
                            putExtra("targetLangFlag", targetLangFlag)
                            putExtra("targetLangName", targetLangName)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "updateOverlay" -> {
                    try {
                        val isTranslating = call.argument<Boolean>("isTranslating") ?: false
                        val isPaused = call.argument<Boolean>("isPaused") ?: false
                        val targetLang = call.argument<String>("targetLang") ?: "HI"
                        val targetLangFlag = call.argument<String>("targetLangFlag") ?: "🇮🇳"
                        val targetLangName = call.argument<String>("targetLangName") ?: "Hindi"
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = FloatingOverlayService.ACTION_UPDATE
                            putExtra("isTranslating", isTranslating)
                            putExtra("isPaused", isPaused)
                            putExtra("targetLang", targetLang)
                            putExtra("targetLangFlag", targetLangFlag)
                            putExtra("targetLangName", targetLangName)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "ensureForeground", "removeOverlayKeepService" -> {
                    try {
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = if (call.method == "ensureForeground")
                                FloatingOverlayService.ACTION_ENSURE_FOREGROUND
                            else
                                FloatingOverlayService.ACTION_REMOVE_OVERLAY_KEEP
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "hideOverlay" -> {
                    try {
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = FloatingOverlayService.ACTION_HIDE
                        }
                        stopService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Live Audio Pipeline MethodChannel & EventChannel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_PIPELINE_CHANNEL)
        pipelineMethodChannel = channel
        val micEventChannel = io.flutter.plugin.common.EventChannel(flutterEngine.dartExecutor.binaryMessenger, MIC_STREAM_CHANNEL)

        micEventChannel.setStreamHandler(object : io.flutter.plugin.common.EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: io.flutter.plugin.common.EventChannel.EventSink?) {
                micEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                micEventSink = null
                stopRecording()
            }
        })

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestInternalAudioPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (mediaProjection != null) {
                            val serviceIntent = Intent(this, FloatingOverlayService::class.java).apply {
                                action = FloatingOverlayService.ACTION_START_FOREGROUND
                                putExtra("hasMediaProjection", true)
                                putExtra("isTranslating", false)
                                putExtra("isPaused", false)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success("granted")
                            return@setMethodCallHandler
                        }
                        try {
                            // Ensure Foreground Service is started ahead of time for Android 14+ MediaProjection,
                            // but DO NOT show any floating overlay icon on screen until dubbing is active!
                            val serviceIntent = Intent(this, FloatingOverlayService::class.java).apply {
                                action = FloatingOverlayService.ACTION_START_FOREGROUND
                                putExtra("isTranslating", false)
                                putExtra("isPaused", false)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }

                            mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                            if (mediaProjectionManager != null) {
                                try { pendingProjectionResult?.success("user_cancelled") } catch (_: Exception) {}
                                pendingProjectionResult = result
                                val captureIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                                    val config = android.media.projection.MediaProjectionConfig.createConfigForDefaultDisplay()
                                    mediaProjectionManager!!.createScreenCaptureIntent(config)
                                } else {
                                    mediaProjectionManager!!.createScreenCaptureIntent()
                                }
                                startActivityForResult(
                                    captureIntent,
                                    REQUEST_MEDIA_PROJECTION
                                )
                            } else {
                                result.success("not_supported")
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Error requesting MediaProjection", e)
                            result.success("not_supported")
                        }
                    } else {
                        // Android 9 or lower does not support internal audio capture
                        result.success("not_supported")
                    }
                }
                "startAudioCapture" -> {
                    val mode = call.argument<String>("mode") ?: "internal"
                    val captureStatus = startRecording(mode)
                    result.success(captureStatus)
                }
                "startMicCapture" -> {
                    val captureStatus = startRecording("mic")
                    result.success(captureStatus["started"] as? Boolean ?: false)
                }
                "stopMicCapture" -> {
                    stopRecording()
                    result.success(true)
                }
                "playPcmChunk" -> {
                    val base64Data = call.argument<String>("data") ?: ""
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    result.success(true) // Return immediately — non-blocking
                    val epoch = flushEpoch
                    audioEnqueueExecutor.execute {
                        // Chunks submitted before a stop/flush/pause must never restart playback afterwards
                        if (epoch == flushEpoch) playPcm(base64Data, sampleRate)
                    }
                }
                "stopAudioPlayback" -> {
                    stopPlayback()
                    result.success(true)
                }
                "flushPlaybackQueue" -> {
                    flushPlayback()
                    result.success(true)
                }
                "setDubbedVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0.0f, 1.0f)
                    userDubbedVolume = vol
                    synchronized(audioTrackLock) {
                        try {
                            audioTrack?.setVolume(vol)
                        } catch (_: Exception) {}
                    }
                    result.success(true)
                }
                "setOriginalVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.0).toFloat().coerceIn(0.0f, 1.0f)
                    userOriginalVolume = vol
                    applyEffectiveVolumeState()
                    result.success(true)
                }
                "setDubbingPaused" -> {
                    val isPaused = call.argument<Boolean>("isPaused") ?: false
                    // Only an auto-resume (speech onset) may replay the short pre-roll captured while paused.
                    // A manual resume must NOT: that audio is old and would be dubbed late.
                    keepPreroll = call.argument<Boolean>("preroll") ?: false
                    isDubbingPaused = isPaused
                    if (isPaused) {
                        flushPlayback()
                    }
                    applyEffectiveVolumeState()
                    result.success(true)
                }
                "isDubbedVoicePlaying" -> {
                    result.success(isDubbedVoicePlaying.get())
                }
                "decodeAudioToPcm16k" -> {
                    val inputPath = call.argument<String>("inputPath") ?: ""
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    Thread {
                        val res = decodeAudioToPcm16k(inputPath, outputPath)
                        runOnUiThread {
                            result.success(res)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private val REQUEST_MEDIA_PROJECTION = 2001
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var pendingProjectionResult: MethodChannel.Result? = null
    private var currentCaptureMode = "internal"

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val acquireProjection = {
                    try {
                        FloatingOverlayService.promoteToMediaProjection()
                        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                            override fun onStop() {
                                FloatingOverlayService.demoteFromMediaProjection()
                                mediaProjection = null
                                abandonAudioFocus()
                                runOnUiThread {
                                    pipelineMethodChannel?.invokeMethod("onMediaProjectionStopped", null)
                                }
                            }
                        }, null)
                        android.util.Log.i("MainActivity", "MediaProjection successfully acquired")
                        pendingProjectionResult?.success("granted")
                    } catch (e: Exception) {
                        FloatingOverlayService.demoteFromMediaProjection()
                        android.util.Log.e("MainActivity", "Failed to obtain MediaProjection", e)
                        pendingProjectionResult?.success("not_supported")
                    }
                    pendingProjectionResult = null
                }

                val hasAcquired = java.util.concurrent.atomic.AtomicBoolean(false)
                val safeAcquireProjection = {
                    if (hasAcquired.compareAndSet(false, true)) {
                        acquireProjection()
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    if (FloatingOverlayService.isForegroundActive) {
                        safeAcquireProjection()
                    } else {
                        val timeoutRunnable = Runnable {
                            if (FloatingOverlayService.onForegroundReadyListener != null) {
                                FloatingOverlayService.onForegroundReadyListener = null
                                FloatingOverlayService.demoteFromMediaProjection()
                                android.util.Log.w("MainActivity", "Timeout waiting for FloatingOverlayService foreground ready")
                                if (hasAcquired.compareAndSet(false, true)) {
                                    pendingProjectionResult?.success("not_supported")
                                    pendingProjectionResult = null
                                }
                            }
                        }
                        mainHandler.postDelayed(timeoutRunnable, 5000L)
                        FloatingOverlayService.onForegroundReadyListener = {
                            mainHandler.removeCallbacks(timeoutRunnable)
                            FloatingOverlayService.onForegroundReadyListener = null
                            runOnUiThread {
                                safeAcquireProjection()
                            }
                        }
                    }
                } else {
                    safeAcquireProjection()
                }
            } else {
                FloatingOverlayService.demoteFromMediaProjection()
                android.util.Log.i("MainActivity", "User pressed back or cancelled app chooser. Stopping service & restoring audio.")
                try {
                    val hideIntent = Intent(this, FloatingOverlayService::class.java).apply {
                        action = FloatingOverlayService.ACTION_HIDE
                    }
                    stopService(hideIntent)
                } catch (_: Exception) {}
                abandonAudioFocus()
                mediaProjection = null
                pendingProjectionResult?.success("user_cancelled")
                pendingProjectionResult = null
            }
        }
    }

    private val AUDIO_PIPELINE_CHANNEL = "com.syncdub.livedub/audio_pipeline"
    private var pipelineMethodChannel: MethodChannel? = null
    private val MIC_STREAM_CHANNEL = "com.syncdub.livedub/mic_stream"
    private var micEventSink: io.flutter.plugin.common.EventChannel.EventSink? = null

    private var audioRecord: AudioRecord? = null
    private val isRecording = java.util.concurrent.atomic.AtomicBoolean(false)
    private var recordThread: Thread? = null

    @Volatile
    private var audioTrack: android.media.AudioTrack? = null
    private val audioTrackLock = Any()
    private var currentTrackSampleRate = 24000
    private var userDubbedVolume = 1.0f
    private var userOriginalVolume = 0.0f

    // Acoustic Echo Protection: Tracks when dubbed speech is actively playing through the speaker
    private val isDubbedVoicePlaying = java.util.concurrent.atomic.AtomicBoolean(false)
    @Volatile
    private var lastDubbedPlaybackTime = 0L
    @Volatile
    private var isHardwareAecActive = false
    private var echoCanceler: android.media.audiofx.AcousticEchoCanceler? = null

    // Non-blocking asynchronous playback queue for 24kHz SyncDub AI speech audio
    private val playbackQueue = java.util.concurrent.LinkedBlockingQueue<ByteArray>()
    private val queuedBytesCount = java.util.concurrent.atomic.AtomicLong(0)
    private val audioEnqueueExecutor = java.util.concurrent.Executors.newSingleThreadExecutor { r ->
        Thread(r, "SyncDubAudioEnqueueThread").apply { priority = Thread.MAX_PRIORITY - 1 }
    }
    private val isPlaying = java.util.concurrent.atomic.AtomicBoolean(false)
    private var playbackThread: Thread? = null

    // Native JitterBuffer matching Chrome extension JitterBuffer.js:
    // 220ms initial cushion on cold start / underrun recovery to absorb WebSocket jitter
    private val isJitterBuffering = java.util.concurrent.atomic.AtomicBoolean(true)
    @Volatile
    private var currentPlaybackSpeed = 1.0f
    @Volatile
    private var isColdRamping = true

    // Pre-cached main-thread Handler: avoids per-chunk Activity context lookup in the hot audio recording path
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private fun ensureAudioTrack(sampleRate: Int) {
        synchronized(audioTrackLock) {
            if (audioTrack == null || currentTrackSampleRate != sampleRate || audioTrack?.state != android.media.AudioTrack.STATE_INITIALIZED) {
                try {
                    audioTrack?.stop()
                    audioTrack?.release()
                } catch (_: Exception) {}
                audioTrack = null

                val minBuf = android.media.AudioTrack.getMinBufferSize(
                    sampleRate,
                    android.media.AudioFormat.CHANNEL_OUT_MONO,
                    android.media.AudioFormat.ENCODING_PCM_16BIT
                )
                // ~200ms hardware buffer: low latency; network jitter is absorbed by the worker pre-roll gate
                val bufferSize = Math.max(minBuf * 3, 9600)

                val trackBuilder = android.media.AudioTrack.Builder()
                    .setAudioAttributes(
                        android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_ASSISTANT)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        android.media.AudioFormat.Builder()
                            .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(android.media.AudioTrack.MODE_STREAM)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    trackBuilder.setPerformanceMode(android.media.AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                }

                audioTrack = trackBuilder.build()

                // Natural 1.0x: PlaybackParams are only touched lazily when a real backlog builds up
                currentPlaybackSpeed = 1.0f

                try {
                    audioTrack?.setVolume(userDubbedVolume)
                } catch (_: Exception) {}
                try {
                    audioTrack?.play()
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error starting AudioTrack playback", e)
                }
                currentTrackSampleRate = sampleRate
                android.util.Log.i("MainActivity", "AudioTrack initialized (USAGE_ASSISTANT, 1.0x Natural Speed): sampleRate=$sampleRate, bufferSize=$bufferSize, userDubbedVolume=$userDubbedVolume")
            }
        }
    }

    @Volatile
    private var isDubbingPaused = false
    // True only for a silence auto-resume: the last ~600ms captured while paused are then sent so the first
    // syllables of the new speech are not clipped. False for every manual resume (old audio is dropped).
    @Volatile
    private var keepPreroll = false

    // Immediate native reaction to a pause/resume tapped on the overlay or notification:
    // input gate + playback flush + audio focus (system volume back to 100%) in one synchronous step.
    private val pauseHint: (Boolean) -> Unit = { paused ->
        keepPreroll = false
        isDubbingPaused = paused
        if (paused) {
            flushPlayback()
        }
        applyEffectiveVolumeState()
    }
    private var audioFocusRequest: android.media.AudioFocusRequest? = null
    private var isDuckingFocusHeld = false

    // ── External playback watcher (instant "video stopped / started" signal) ──────────────────────────
    // AudioPlaybackCallback reports when another app's media player really starts or stops, so dubbing can
    // pause the moment the video is paused instead of waiting for the amplitude silence timer. Only MEDIA /
    // GAME / UNKNOWN usages count; our own dub track is USAGE_ASSISTANT and notification sounds use other
    // usages, so neither can look like "video playing". The first "active" must be seen before any "stopped"
    // is reported, so apps that never expose their player simply keep the old silence-based behaviour.
    private var playbackCallback: android.media.AudioManager.AudioPlaybackCallback? = null
    private var externalMediaActive: Boolean? = null
    private var externalMediaSeen = false
    private var externalIdleCheck: Runnable? = null
    private val externalIdleDebounceMs = 300L // rides over the gap between two Reels / playlist items

    private fun hasExternalMedia(configs: List<android.media.AudioPlaybackConfiguration>): Boolean {
        for (c in configs) {
            val usage = try { c.audioAttributes.usage } catch (_: Exception) { continue }
            if (usage == AudioAttributes.USAGE_MEDIA ||
                usage == AudioAttributes.USAGE_GAME ||
                usage == AudioAttributes.USAGE_UNKNOWN) {
                return true
            }
        }
        return false
    }

    private fun notifyExternalPlayback(active: Boolean) {
        if (externalMediaActive == active) return
        externalMediaActive = active
        android.util.Log.i("MainActivity", "External media playback active=$active")
        try {
            pipelineMethodChannel?.invokeMethod("onExternalPlaybackChanged", mapOf("active" to active))
        } catch (_: Exception) {}
    }

    private fun evaluateExternalPlayback(configs: List<android.media.AudioPlaybackConfiguration>) {
        if (!isRecording.get()) return
        if (hasExternalMedia(configs)) {
            externalIdleCheck?.let { mainHandler.removeCallbacks(it) }
            externalIdleCheck = null
            externalMediaSeen = true
            notifyExternalPlayback(true)
            return
        }
        if (!externalMediaSeen || externalMediaActive == false || externalIdleCheck != null) return
        val check = Runnable {
            externalIdleCheck = null
            if (!isRecording.get()) return@Runnable
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return@Runnable
            val fresh = try { am.activePlaybackConfigurations } catch (_: Exception) { return@Runnable }
            if (!hasExternalMedia(fresh)) notifyExternalPlayback(false)
        }
        externalIdleCheck = check
        mainHandler.postDelayed(check, externalIdleDebounceMs)
    }

    private fun startPlaybackWatch() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (playbackCallback != null) return
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        externalMediaActive = null
        externalMediaSeen = false
        val cb = object : AudioManager.AudioPlaybackCallback() {
            override fun onPlaybackConfigChanged(configs: MutableList<android.media.AudioPlaybackConfiguration>?) {
                evaluateExternalPlayback(configs ?: emptyList())
            }
        }
        try {
            am.registerAudioPlaybackCallback(cb, mainHandler)
            playbackCallback = cb
            evaluateExternalPlayback(am.activePlaybackConfigurations)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "registerAudioPlaybackCallback failed", e)
        }
    }

    private fun stopPlaybackWatch() {
        externalIdleCheck?.let { mainHandler.removeCallbacks(it) }
        externalIdleCheck = null
        externalMediaActive = null
        externalMediaSeen = false
        val cb = playbackCallback ?: return
        playbackCallback = null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.unregisterAudioPlaybackCallback(cb)
        } catch (_: Exception) {}
    }


    private val legacyFocusChangeListener = android.media.AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            android.media.AudioManager.AUDIOFOCUS_LOSS -> {
                // Permanent loss: another app owns focus now. Do NOT grab it back (would pause/duck their playback in a loop).
                isDuckingFocusHeld = false
                audioFocusRequest = null
            }
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                isDuckingFocusHeld = false
                if (isRecording.get() && !isDubbingPaused && userOriginalVolume < 0.85f) {
                    mainHandler.postDelayed({ applyEffectiveVolumeState() }, 300L)
                }
            }
            android.media.AudioManager.AUDIOFOCUS_GAIN -> {
                isDuckingFocusHeld = true
            }
        }
    }

    /**
     * Chrome Extension Audio Routing Parity:
     * Pure Audio Focus Ducking (AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK via USAGE_ASSISTANT).
     * Strictly NEVER modifies system STREAM_MUSIC volume!
     * - When translation is active and userOriginalVolume < 0.85f:
     *   Requests transient ducking focus so Android OS attenuates background media (YouTube).
     * - When translation is paused, dubbing stops, or userOriginalVolume >= 0.85f:
     *   Abandons audio focus immediately so background media plays at 100% full volume.
     */
    @Synchronized
    private fun applyEffectiveVolumeState() {
        if (!isRecording.get() || isDubbingPaused || userOriginalVolume >= 0.85f) {
            abandonAudioFocus()
            return
        }

        // Active dubbing with ducking desired
        requestDuckingFocus()
    }

    private fun requestDuckingFocus() {
        try {
            val audioMgr = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (audioFocusRequest == null) {
                    audioFocusRequest = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                        .setAudioAttributes(
                            android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_ASSISTANT)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                        )
                        .setWillPauseWhenDucked(false)
                        .setAcceptsDelayedFocusGain(false)
                        .setOnAudioFocusChangeListener(legacyFocusChangeListener)
                        .build()
                }
                val res = audioMgr.requestAudioFocus(audioFocusRequest!!)
                isDuckingFocusHeld = (res == android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                android.util.Log.i("MainActivity", "Audio focus requested (USAGE_ASSISTANT MAY_DUCK): granted=$isDuckingFocusHeld (result=$res)")
            } else {
                @Suppress("DEPRECATION")
                val res = audioMgr.requestAudioFocus(
                    legacyFocusChangeListener,
                    android.media.AudioManager.STREAM_MUSIC,
                    android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
                isDuckingFocusHeld = (res == android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
            }
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to request audio focus ducking", e)
        }
    }

    private fun abandonAudioFocus() {
        if (!isDuckingFocusHeld && audioFocusRequest == null) return
        try {
            val audioMgr = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioFocusRequest != null) {
                audioMgr.abandonAudioFocusRequest(audioFocusRequest!!)
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                audioMgr.abandonAudioFocus(legacyFocusChangeListener)
            }
            isDuckingFocusHeld = false
            android.util.Log.i("MainActivity", "Audio focus: ABANDONED (Full volume restored)")
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to abandon audio focus", e)
        }
    }

    /**
     * Scales 16-bit PCM little-endian audio samples instantaneously by volume factor (0.0 to 1.0).
     * Ensures immediate software volume attenuation with zero hardware delay.
     */
    private fun applyPcmVolume(pcm: ByteArray, volume: Float): ByteArray {
        val clampedVol = volume.coerceIn(0f, 1f)
        if (clampedVol <= 0.001f) {
            pcm.fill(0) // 0 volume = silence in-place
            return pcm
        }
        if (clampedVol >= 0.999f) {
            return pcm // 100% volume = original PCM untouched
        }
        // In-place volume scaling — zero allocation
        for (i in 0 until pcm.size - 1 step 2) {
            val low = pcm[i].toInt() and 0xFF
            val high = pcm[i + 1].toInt()
            val sample = (high shl 8) or low
            val newSample = (sample * clampedVol).toInt().coerceIn(-32768, 32767)
            pcm[i] = (newSample and 0xFF).toByte()
            pcm[i + 1] = ((newSample shr 8) and 0xFF).toByte()
        }
        return pcm
    }

    /**
     * Applies a 4ms linear micro-ramp on cold start or after underrun
     * to eliminate speaker pops/clicks (matching Chrome offscreen.js line 2564).
     */
    private fun applySoftRampIn(pcm: ByteArray): ByteArray {
        val rampBytes = Math.min(192, pcm.size)
        if (rampBytes <= 4) return pcm
        // In-place ramp — zero allocation
        val totalSamples = rampBytes / 2
        for (s in 0 until totalSamples) {
            val factor = s.toFloat() / totalSamples.toFloat()
            val idx = s * 2
            val low = pcm[idx].toInt() and 0xFF
            val high = pcm[idx + 1].toInt()
            val sample = (high shl 8) or low
            val newSample = (sample * factor).toInt().coerceIn(-32768, 32767)
            pcm[idx] = (newSample and 0xFF).toByte()
            pcm[idx + 1] = ((newSample shr 8) and 0xFF).toByte()
        }
        return pcm
    }

    // ── Low-latency gapless playback scheduler ───────────────────────────
    // PREROLL_MS: tiny cushion at the start of each utterance (cloud audio arrives faster than realtime).
    // MAX_GATE_WAIT_MS: hard cap so a short first/last chunk can never sit in the queue waiting for more audio.
    private val PREROLL_MS = 60L
    private val MAX_GATE_WAIT_MS = 100L
    // Wall-clock estimate of when AudioTrack runs out of queued audio (= REAL underrun detection)
    @Volatile
    private var trackDrainAtMs = 0L
    @Volatile
    private var gateWaitStartMs = 0L
    // Bumped by every stopPlayback(): an old worker thread can never survive next to a new one
    @Volatile
    private var playbackGeneration = 0
    // Bumped by flushPlayback()/stopPlayback(): invalidates chunks still waiting in audioEnqueueExecutor
    @Volatile
    private var flushEpoch = 0

    @Synchronized
    private fun startPlaybackWorker() {
        if (isPlaying.get() && playbackThread != null && playbackThread!!.isAlive) return

        isPlaying.set(true)
        val myGen = playbackGeneration
        playbackThread = Thread {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_URGENT_AUDIO)
            while (isPlaying.get() && myGen == playbackGeneration) {
                try {
                    val bytesPerMs = Math.max((currentTrackSampleRate * 2) / 1000, 48)

                    // Pre-roll gate (start of utterance / after a REAL underrun only).
                    // Opens as soon as PREROLL_MS is queued OR MAX_GATE_WAIT_MS has passed - whichever is first.
                    if (isJitterBuffering.get()) {
                        if (playbackQueue.isEmpty()) {
                            gateWaitStartMs = 0L
                            try { Thread.sleep(4) } catch (_: InterruptedException) { break }
                            continue
                        }
                        val gateNow = System.currentTimeMillis()
                        if (gateWaitStartMs == 0L) gateWaitStartMs = gateNow
                        val queuedMs = queuedBytesCount.get() / bytesPerMs
                        if (queuedMs < PREROLL_MS && (gateNow - gateWaitStartMs) < MAX_GATE_WAIT_MS) {
                            try { Thread.sleep(4) } catch (_: InterruptedException) { break }
                            continue
                        }
                        isJitterBuffering.set(false)
                        isColdRamping = true
                        gateWaitStartMs = 0L
                    }

                    val chunk = playbackQueue.poll(20, java.util.concurrent.TimeUnit.MILLISECONDS)
                    if (chunk != null && chunk.isNotEmpty()) {
                        queuedBytesCount.addAndGet(-chunk.size.toLong())
                        if (!isPlaying.get() || myGen != playbackGeneration) break
                        isDubbedVoicePlaying.set(true)
                        lastDubbedPlaybackTime = System.currentTimeMillis()

                        // Adaptive catch-up (same table as Chrome extension JitterBuffer.js); 1.0x in normal operation.
                        val remainingQueuedBytes = queuedBytesCount.get().toInt()
                        val queueLeadMs = remainingQueuedBytes / bytesPerMs
                        val targetSpeed = when {
                            queueLeadMs <= 800 -> 1.0f
                            queueLeadMs <= 1800 -> 1.03f
                            queueLeadMs <= 3000 -> 1.06f
                            queueLeadMs <= 4500 -> 1.12f
                            else -> 1.18f
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Math.abs(currentPlaybackSpeed - targetSpeed) >= 0.02f) {
                            synchronized(audioTrackLock) {
                                try {
                                    val params = audioTrack?.playbackParams
                                    if (params != null) {
                                        params.speed = targetSpeed
                                        params.pitch = 1.0f
                                        audioTrack?.playbackParams = params
                                        currentPlaybackSpeed = targetSpeed
                                    }
                                } catch (_: Exception) {}
                            }
                        }

                        // Volume is applied ONCE via AudioTrack.setVolume(); scaling PCM as well squared the attenuation
                        var scaledChunk = chunk
                        if (isColdRamping) {
                            scaledChunk = applySoftRampIn(scaledChunk)
                            isColdRamping = false
                        }

                        val track = synchronized(audioTrackLock) {
                            if (!isPlaying.get() || myGen != playbackGeneration) return@synchronized null
                            if (audioTrack == null || audioTrack?.state != android.media.AudioTrack.STATE_INITIALIZED) {
                                ensureAudioTrack(currentTrackSampleRate)
                            }
                            if (audioTrack?.playState != android.media.AudioTrack.PLAYSTATE_PLAYING) {
                                try { audioTrack?.play() } catch (_: Exception) {}
                            }
                            audioTrack
                        }

                        if (track != null && isPlaying.get() && myGen == playbackGeneration) {
                            val writeStartMs = System.currentTimeMillis()
                            val written = try {
                                track.write(scaledChunk, 0, scaledChunk.size)
                            } catch (_: Exception) {
                                -1
                            }
                            if (written >= 0) {
                                // Track how long the AudioTrack stays busy so we only re-arm the gate on a TRUE underrun
                                val chunkMs = (scaledChunk.size / bytesPerMs).toLong()
                                val adjMs = (chunkMs / currentPlaybackSpeed).toLong()
                                trackDrainAtMs = Math.max(trackDrainAtMs, writeStartMs) + adjMs
                            }
                            if (written < 0 && isPlaying.get()) {
                                android.util.Log.w("MainActivity", "AudioTrack write error ($written) - reinitializing track")
                                synchronized(audioTrackLock) {
                                    if (audioTrack === track && isPlaying.get()) {
                                        try {
                                            audioTrack?.stop()
                                            audioTrack?.release()
                                        } catch (_: Exception) {}
                                        audioTrack = null
                                        ensureAudioTrack(currentTrackSampleRate)
                                    }
                                }
                            }
                        }
                        lastDubbedPlaybackTime = System.currentTimeMillis()
                    } else {
                        // Queue is empty. That is NOT an underrun while AudioTrack still holds audio.
                        // Only a real drain re-arms the pre-roll gate (old code re-armed after every 50ms gap = stutter).
                        val idleNow = System.currentTimeMillis()
                        if (playbackQueue.isEmpty() && idleNow >= trackDrainAtMs + 15L) {
                            isJitterBuffering.set(true)
                        }
                        if (isDubbedVoicePlaying.get() && idleNow > trackDrainAtMs + 300L) {
                            isDubbedVoicePlaying.set(false)
                        }
                    }
                } catch (_: InterruptedException) {
                    break
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error in AudioTrack playback worker", e)
                }
            }
            isDubbedVoicePlaying.set(false)
        }.apply {
            name = "SyncDubAudioTrackPlaybackThread"
            start()
        }
    }

    @Synchronized
    private fun startRecording(preferredMode: String = "internal"): Map<String, Any> {
        if (isRecording.get()) {
            return mapOf("started" to true, "mode" to currentCaptureMode)
        }
        try {
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = Math.max(minBufferSize * 2, 4096)

            var usedInternal = false

            // Android 10+ (API 29+) AudioPlaybackCapture for Direct Internal Video Audio Capture!
            if (preferredMode == "internal" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && mediaProjection != null) {
                try {
                    val playbackConfigBuilder = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                        .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                        .addMatchingUsage(AudioAttributes.USAGE_GAME)
                        .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                    
                    // CRITICAL: Exclude our own app's audio output so AudioRecord doesn't capture
                    // its own AudioTrack playback and send it back to SyncDub AI (infinite repetition loop)
                    playbackConfigBuilder.excludeUid(android.os.Process.myUid())

                    val playbackConfig = playbackConfigBuilder.build()

                    audioRecord = AudioRecord.Builder()
                        .setAudioPlaybackCaptureConfig(playbackConfig)
                        .setAudioFormat(
                            AudioFormat.Builder()
                                .setEncoding(audioFormat)
                                .setSampleRate(sampleRate)
                                .setChannelMask(channelConfig)
                                .build()
                        )
                        .setBufferSizeInBytes(bufferSize)
                        .build()

                    usedInternal = (audioRecord?.state == AudioRecord.STATE_INITIALIZED)
                    if (usedInternal) {
                        try {
                            audioRecord?.startRecording()
                            currentCaptureMode = "internal"
                            android.util.Log.i("MainActivity", "Internal AudioPlaybackCapture recording started successfully")
                        } catch (startErr: Exception) {
                            android.util.Log.e("MainActivity", "Internal AudioPlaybackCapture startRecording failed ($startErr)", startErr)
                            try {
                                audioRecord?.stop()
                                audioRecord?.release()
                            } catch (_: Exception) {}
                            audioRecord = null
                            releaseProjectionAfterFailure()
                            usedInternal = false
                        }
                    } else {
                        android.util.Log.e("MainActivity", "AudioPlaybackCapture uninitialized")
                        try { audioRecord?.release() } catch (_: Exception) {}
                        audioRecord = null
                        releaseProjectionAfterFailure()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Internal audio playback capture setup failed", e)
                    try { audioRecord?.release() } catch (_: Exception) {}
                    audioRecord = null
                    releaseProjectionAfterFailure()
                    usedInternal = false
                }
            }

            if (!usedInternal && preferredMode == "internal") {
                android.util.Log.e("MainActivity", "Internal screen audio capture failed to initialize")
                return mapOf("started" to false, "mode" to "internal", "error" to "Internal audio capture failed to initialize. Please allow screen audio capture.")
            }

            if (!usedInternal) {
                // Fallback to Physical Microphone Loopback with Hardware Acoustic Echo Cancellation
                try {
                    audioRecord = AudioRecord(
                        MediaRecorder.AudioSource.MIC,
                        sampleRate,
                        channelConfig,
                        audioFormat,
                        bufferSize
                    )
                } catch (_: Exception) {}

                if (audioRecord == null || audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    try { audioRecord?.release() } catch (_: Exception) {}
                    audioRecord = AudioRecord(
                        MediaRecorder.AudioSource.DEFAULT,
                        sampleRate,
                        channelConfig,
                        audioFormat,
                        bufferSize
                    )
                }

                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    android.util.Log.e("MainActivity", "Physical MIC AudioRecord initialization failed (state=${audioRecord?.state})")
                    try { audioRecord?.release() } catch (_: Exception) {}
                    audioRecord = null
                    return mapOf("started" to false, "mode" to "none", "error" to "AudioRecord uninitialized")
                }

                // Enable device hardware Acoustic Echo Cancellation (AEC) if supported
                isHardwareAecActive = false
                try {
                    echoCanceler?.release()
                } catch (_: Exception) {}
                echoCanceler = null
                if (android.media.audiofx.AcousticEchoCanceler.isAvailable()) {
                    try {
                        val aec = android.media.audiofx.AcousticEchoCanceler.create(audioRecord!!.audioSessionId)
                        if (aec != null) {
                            aec.enabled = true
                            echoCanceler = aec
                            isHardwareAecActive = aec.enabled
                            android.util.Log.i("MainActivity", "Hardware AcousticEchoCanceler enabled=$isHardwareAecActive")
                        }
                    } catch (e: Exception) {
                        android.util.Log.w("MainActivity", "AcousticEchoCanceler setup failed: $e")
                    }
                }

                audioRecord?.startRecording()
                currentCaptureMode = "mic"
                android.util.Log.i("MainActivity", "Physical MIC AudioRecord started successfully with echo cancellation")
            }

            isRecording.set(true)
            isDubbingPaused = false
            android.util.Log.i("MainActivity", "AudioRecord successfully active in $currentCaptureMode mode (bufferSize=$bufferSize)")
            runOnUiThread {
                applyEffectiveVolumeState()
                if (currentCaptureMode == "internal") startPlaybackWatch()
            }

            val rec = audioRecord ?: return mapOf("started" to false, "mode" to "none", "error" to "AudioRecord missing")
            recordThread = Thread {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
                // Read in 20ms chunks (320 samples = 640 bytes at 16kHz) for immediate RMS volume calculation
                val pcmBuffer = ByteArray(640)
                // Outbound PCM Batcher (Matching Chrome extension OutboundPcmBatcher):
                // Accumulates 20ms worklet chunks into 100ms frames (1600 samples = 3200 bytes at 16kHz).
                // Reduces WebSocket packet frequency from 50/s to 10/s, dramatically stabilizing network streaming.
                // 40ms frames (640 samples = 1280 bytes @16kHz): lowest practical latency for Gemini Live input
                val outboundBatchBuffer = java.io.ByteArrayOutputStream(1280)
                // Keeps the last ~600ms while paused so speech onset right after auto-resume is not clipped
                val pauseRing = java.util.ArrayDeque<ByteArray>()
                var wasPaused = false
                var ampTick = 0

                while (isRecording.get()) {
                    val read = try { rec.read(pcmBuffer, 0, pcmBuffer.size) } catch (_: Exception) { AudioRecord.ERROR_DEAD_OBJECT }
                    if (read > 0) {
                        // ACOUSTIC ECHO PROTECTION:
                        // When hardware AEC is unavailable, mute microphone chunks during dubbed playback hangover
                        // so physical mic does not re-capture the phone's own translated voice (prevents repeating loops)
                        val isEcho = (currentCaptureMode == "mic") && !isHardwareAecActive &&
                                (isDubbedVoicePlaying.get() ||
                                        System.currentTimeMillis() - lastDubbedPlaybackTime < 400L)
                        if (isEcho) {
                            java.util.Arrays.fill(pcmBuffer, 0, read, 0.toByte())
                        }

                        // Calculate RMS Amplitude on the 20ms chunk (matching calculatePcmRms in Chrome offscreen.js)
                        var sumOfSquares = 0.0
                        val sampleCount = read / 2
                        for (i in 0 until read step 2) {
                            val sample = ((pcmBuffer[i + 1].toInt() shl 8) or (pcmBuffer[i].toInt() and 0xFF)).toShort()
                            val normalized = sample.toDouble() / 32768.0
                            sumOfSquares += normalized * normalized
                        }
                        val rms = if (sampleCount > 0) Math.sqrt(sumOfSquares / sampleCount) else 0.0
                        val normalizedAmp = rms.coerceIn(0.0, 1.0)

                        // CHROME EXTENSION PARITY & REAL-TIME AUTO-RESUME:
                        // When translation is paused or video is silent:
                        // Discard outbound PCM chunks to avoid sending to backend WebSocket,
                        // BUT STILL EMIT AMPLITUDE to Flutter so auto-resume can trigger immediately!
                        if (isDubbingPaused) {
                            outboundBatchBuffer.reset()
                            wasPaused = true
                            pauseRing.addLast(pcmBuffer.copyOf(read))
                            while (pauseRing.size > 30) pauseRing.removeFirst()
                            if ((++ampTick % 3) == 0) {
                                val eventData = mapOf(
                                    "pcm" to "",
                                    "amp" to normalizedAmp,
                                    "bytes" to 0,
                                    "mode" to currentCaptureMode
                                )
                                mainHandler.post {
                                    micEventSink?.success(eventData)
                                }
                            }
                            continue
                        }
                        if (wasPaused) {
                            wasPaused = false
                            // Silence auto-resume only: replay the last ~600ms so the first syllables are not clipped.
                            // Manual/overlay resume: everything captured while paused is stale and is dropped.
                            if (keepPreroll) {
                                while (pauseRing.isNotEmpty()) {
                                    val old = pauseRing.removeFirst()
                                    outboundBatchBuffer.write(old, 0, old.size)
                                }
                            } else {
                                pauseRing.clear()
                            }
                            keepPreroll = false
                        }

                        // Accumulate samples into 100ms outbound batch:
                        outboundBatchBuffer.write(pcmBuffer, 0, read)

                        if (outboundBatchBuffer.size() >= 1280) {
                            val batchBytes = outboundBatchBuffer.toByteArray()
                            outboundBatchBuffer.reset()
                            val base64Data = android.util.Base64.encodeToString(batchBytes, 0, batchBytes.size, android.util.Base64.NO_WRAP)
                            val eventData = mapOf(
                                "pcm" to base64Data,
                                "amp" to normalizedAmp,
                                "bytes" to batchBytes.size,
                                "mode" to currentCaptureMode
                            )
                            mainHandler.post {
                                micEventSink?.success(eventData)
                            }
                        } else if ((++ampTick % 3) == 0) {
                            // Amplitude-only update (throttled): keeps the UI isolate free for audio I/O
                            val eventData = mapOf(
                                "pcm" to "",
                                "amp" to normalizedAmp,
                                "bytes" to 0,
                                "mode" to currentCaptureMode
                            )
                            mainHandler.post {
                                micEventSink?.success(eventData)
                            }
                        }
                    } else {
                        if (read == AudioRecord.ERROR_DEAD_OBJECT || read == AudioRecord.ERROR_INVALID_OPERATION) {
                            android.util.Log.e("MainActivity", "AudioRecord read failed ($read) - leaving capture loop")
                            break
                        }
                        // Prevent tight CPU spin loop if AudioRecord is temporarily not delivering samples or in error state
                        try {
                            Thread.sleep(20)
                        } catch (_: InterruptedException) {
                            break
                        }
                    }
                }

                // Flush any remaining samples when recording thread exits
                if (outboundBatchBuffer.size() > 0) {
                    val remainingBytes = outboundBatchBuffer.toByteArray()
                    outboundBatchBuffer.reset()
                    val base64Data = android.util.Base64.encodeToString(remainingBytes, 0, remainingBytes.size, android.util.Base64.NO_WRAP)
                    mainHandler.post {
                        micEventSink?.success(mapOf(
                            "pcm" to base64Data,
                            "amp" to 0.0,
                            "bytes" to remainingBytes.size,
                            "mode" to currentCaptureMode
                        ))
                    }
                }
            }.apply {
                name = "SyncDubAudioRecordThread"
                start()
            }
            return mapOf("started" to true, "mode" to currentCaptureMode)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start AudioRecord", e)
            try { audioRecord?.release() } catch (_: Exception) {}
            audioRecord = null
            try { echoCanceler?.release() } catch (_: Exception) {}
            echoCanceler = null
            return mapOf("started" to false, "mode" to "none", "error" to (e.message ?: ""))
        }
    }

    @Synchronized
    private fun stopRecording() {
        isRecording.set(false)
        isDubbingPaused = false
        isHardwareAecActive = false
        try {
            echoCanceler?.release()
        } catch (_: Exception) {}
        echoCanceler = null
        try {
            val worker = recordThread
            recordThread = null
            try { audioRecord?.stop() } catch (_: Exception) {}
            worker?.interrupt()
            try { worker?.join(500) } catch (_: InterruptedException) {}
            audioRecord?.release()
            audioRecord = null
            android.util.Log.i("MainActivity", "AudioRecord stopped (MediaProjection preserved for session)")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping AudioRecord", e)
        }
        runOnUiThread {
            stopPlaybackWatch()
            applyEffectiveVolumeState()
        }
    }

    private fun releaseProjectionAfterFailure() {
        val projection = mediaProjection
        mediaProjection = null
        try { projection?.stop() } catch (_: Exception) {}
    }

    private fun playPcm(base64Data: String, sampleRate: Int) {
        if (base64Data.isEmpty() || isDubbingPaused) return
        try {
            val bytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT)
            if (bytes == null || bytes.isEmpty()) return

            ensureAudioTrack(sampleRate)
            startPlaybackWorker()

            val bytesPerMs = Math.max((sampleRate * 2) / 1000, 48)
            // CHROME EXTENSION PARITY: 6-Second Ceiling (DEFAULT_MAX_QUEUE_LEAD_SEC = 6.0s)
            // Headroom allows natural sentence bursts while preventing multi-second delay buildup
            val maxBacklogBytes = 6000 * bytesPerMs
            var totalQueuedBytes = queuedBytesCount.get().toInt()
            // Trim excessive backlog (> 3000ms) immediately to retain real-time synchronicity
            while (totalQueuedBytes > maxBacklogBytes) {
                val dropped = playbackQueue.poll() ?: break
                queuedBytesCount.addAndGet(-dropped.size.toLong())
                totalQueuedBytes -= dropped.size
            }
            playbackQueue.offer(bytes)
            queuedBytesCount.addAndGet(bytes.size.toLong())
            totalQueuedBytes = queuedBytesCount.get().toInt()

        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error queueing PCM audio chunk", e)
        }
    }

    /**
     * Instantly empties the audio scheduler queue and flushes AudioTrack hardware buffers
     * without destroying the AudioTrack instance, matching Chrome extension flushAudioQueue(true).
     */
    private fun flushPlayback() {
        flushEpoch++
        playbackQueue.clear()
        queuedBytesCount.set(0)
        synchronized(audioTrackLock) {
            try {
                audioTrack?.pause()
                audioTrack?.flush()
                audioTrack?.play()
            } catch (_: Exception) {}
        }
        isJitterBuffering.set(true)
        isColdRamping = true
        currentPlaybackSpeed = 1.0f
        trackDrainAtMs = 0L
        gateWaitStartMs = 0L
        isDubbedVoicePlaying.set(false)
        android.util.Log.i("MainActivity", "Playback queue & AudioTrack flushed immediately")
    }

    private fun stopPlayback() {
        flushEpoch++
        isPlaying.set(false)
        playbackGeneration++
        trackDrainAtMs = 0L
        gateWaitStartMs = 0L
        isDubbedVoicePlaying.set(false)
        isJitterBuffering.set(true)
        isColdRamping = true
        playbackQueue.clear()
        queuedBytesCount.set(0)
        try {
            playbackThread?.interrupt()
            playbackThread = null
            synchronized(audioTrackLock) {
                try {
                    audioTrack?.stop()
                    audioTrack?.flush()
                    audioTrack?.release()
                } catch (_: Exception) {}
                audioTrack = null
            }
            android.util.Log.i("MainActivity", "AudioTrack stopped & released")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping AudioTrack", e)
        }
        applyEffectiveVolumeState()
    }

    /**
     * Decodes any audio file (AAC, M4A, MP4, Opus, WebM, OGG) to 16kHz 16-bit Mono PCM
     * using Android native MediaExtractor and hardware MediaCodec.
     * Runs ultra-fast (~20x-50x real-time), producing pure raw PCM for SyncDub AI Live Translate.
     */
    private fun decodeAudioToPcm16k(inputPath: String, outputPath: String): Map<String, Any> {
        val inputFile = java.io.File(inputPath)
        if (!inputFile.exists() || inputFile.length() == 0L) {
            return mapOf("success" to false, "error" to "Input audio file is empty or does not exist")
        }

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var outStream: java.io.BufferedOutputStream? = null

        try {
            extractor.setDataSource(inputPath)
            var audioTrackIndex = -1
            var inputFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    inputFormat = f
                    break
                }
            }

            if (audioTrackIndex < 0 || inputFormat == null) {
                return mapOf("success" to false, "error" to "No audio stream found in media file")
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME) ?: ""
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(inputFormat, null, null, 0)
            codec.start()

            val outFile = java.io.File(outputPath)
            outFile.parentFile?.mkdirs()
            outStream = java.io.BufferedOutputStream(java.io.FileOutputStream(outFile), 65536)

            val bufferInfo = MediaCodec.BufferInfo()
            var isInputEOS = false
            var isOutputEOS = false
            val timeoutUs = 5000L

            var currentSampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else 44100
            var currentChannels = if (inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else 2

            var totalPcmBytes = 0L
            val resampler = StreamResampler()

            while (!isOutputEOS) {
                if (!isInputEOS) {
                    val inputIndex = codec.dequeueInputBuffer(timeoutUs)
                    if (inputIndex >= 0) {
                        val inputBuf = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            codec.getInputBuffer(inputIndex)
                        } else {
                            @Suppress("DEPRECATION")
                            codec.inputBuffers[inputIndex]
                        }
                        if (inputBuf != null) {
                            val sampleSize = extractor.readSampleData(inputBuf, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inputIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isInputEOS = true
                            } else {
                                val timeUs = extractor.sampleTime
                                codec.queueInputBuffer(inputIndex, 0, sampleSize, timeUs, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
                if (outputIndex >= 0) {
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isOutputEOS = true
                    }
                    if (bufferInfo.size > 0) {
                        val outputBuf = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            codec.getOutputBuffer(outputIndex)
                        } else {
                            @Suppress("DEPRECATION")
                            codec.outputBuffers[outputIndex]
                        }

                        if (outputBuf != null) {
                            outputBuf.position(bufferInfo.offset)
                            outputBuf.limit(bufferInfo.offset + bufferInfo.size)
                            val chunk = ByteArray(bufferInfo.size)
                            outputBuf.get(chunk)

                            val resampled = resampleTo16kMono(chunk, currentSampleRate, currentChannels, resampler)
                            if (resampled.isNotEmpty()) {
                                outStream.write(resampled)
                                totalPcmBytes += resampled.size
                            }
                        }
                    }
                    codec.releaseOutputBuffer(outputIndex, false)
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = codec.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        currentSampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        currentChannels = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    android.util.Log.i("MainActivity", "Audio decoder format changed: rate=$currentSampleRate, ch=$currentChannels")
                }
            }

            outStream.flush()
            android.util.Log.i("MainActivity", "Decoded audio to 16k PCM: $totalPcmBytes bytes (${totalPcmBytes / 32000.0}s)")
            return mapOf(
                "success" to true,
                "pcmBytes" to totalPcmBytes,
                "durationSec" to (totalPcmBytes.toDouble() / 32000.0)
            )
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in decodeAudioToPcm16k", e)
            return mapOf("success" to false, "error" to (e.message ?: "Unknown decode error"))
        } finally {
            try { outStream?.close() } catch (_: Exception) {}
            try {
                codec?.stop()
                codec?.release()
            } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }
    }



    /**
     * Resamples raw 16-bit PCM bytes from (inSampleRate, inChannels) to 16000Hz 16-bit Mono.
     * Uses stereo-to-mono downmixing and linear interpolation for crisp, artifact-free speech.
     */
    private fun resampleTo16kMono(chunkBytes: ByteArray, inSampleRate: Int, inChannels: Int, rs: StreamResampler): ByteArray {
        if (chunkBytes.isEmpty()) return ByteArray(0)
        val channels = if (inChannels > 0) inChannels else 1
        val bytesPerFrame = channels * 2
        val totalFrames = chunkBytes.size / bytesPerFrame
        if (totalFrames <= 0) return ByteArray(0)

        val monoSamples = ShortArray(totalFrames)
        if (channels == 2) {
            for (k in 0 until totalFrames) {
                val offset = k * 4
                val left = ((chunkBytes[offset + 1].toInt() shl 8) or (chunkBytes[offset].toInt() and 0xFF)).toShort()
                val right = ((chunkBytes[offset + 3].toInt() shl 8) or (chunkBytes[offset + 2].toInt() and 0xFF)).toShort()
                val avg = (left.toInt() + right.toInt()) / 2
                monoSamples[k] = avg.coerceIn(-32768, 32767).toShort()
            }
        } else {
            for (k in 0 until totalFrames) {
                val offset = k * 2
                val sample = ((chunkBytes[offset + 1].toInt() shl 8) or (chunkBytes[offset].toInt() and 0xFF)).toShort()
                monoSamples[k] = sample
            }
        }

        return rs.process(monoSamples, inSampleRate)
    }

    /** Linear resampler that carries its fractional position and last sample from chunk to chunk. */
    private class StreamResampler {
        private var pos = 0.0
        private var prev: Short? = null

        fun process(mono: ShortArray, inRate: Int): ByteArray {
            val n = mono.size
            if (n == 0) return ByteArray(0)
            if (inRate == 16000) {
                val o = ByteArray(n * 2)
                for (i in 0 until n) {
                    val s = mono[i].toInt()
                    o[i * 2] = (s and 0xFF).toByte()
                    o[i * 2 + 1] = ((s shr 8) and 0xFF).toByte()
                }
                return o
            }
            val ratio = inRate.toDouble() / 16000.0
            val out = java.io.ByteArrayOutputStream(((n / ratio).toInt() + 4) * 2)
            val p = prev
            while (true) {
                val i0 = Math.floor(pos).toInt()
                if (i0 + 1 >= n) break
                val frac = pos - i0
                val a = if (i0 < 0) (p ?: mono[0]).toDouble() else mono[i0].toDouble()
                val b = mono[i0 + 1].toDouble()
                val v = (a * (1.0 - frac) + b * frac).toInt().coerceIn(-32768, 32767)
                out.write(v and 0xFF)
                out.write((v shr 8) and 0xFF)
                pos += ratio
            }
            pos -= n
            prev = mono[n - 1]
            return out.toByteArray()
        }
    }

    override fun onDestroy() {
        overlayChannel = null
        pauseHintHandler = null
        pipelineMethodChannel = null
        micEventSink = null
        abandonAudioFocus()
        stopRecording()
        stopPlayback()
        try {
            val hideIntent = Intent(this, FloatingOverlayService::class.java).apply {
                action = FloatingOverlayService.ACTION_HIDE
            }
            stopService(hideIntent)
        } catch (_: Exception) {}
        try {
            mediaProjection?.stop()
        } catch (_: Exception) {}
        mediaProjection = null
        super.onDestroy()
    }
}
