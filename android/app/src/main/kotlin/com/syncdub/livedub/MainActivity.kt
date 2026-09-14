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

        fun triggerPauseResume() {
            overlayChannel?.invokeMethod("onPauseResumeToggled", null)
        }

        fun triggerOverlayClosed() {
            overlayChannel?.invokeMethod("onOverlayClosed", null)
        }

        fun triggerLanguageCycle() {
            overlayChannel?.invokeMethod("onLanguageCycleRequested", null)
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
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = FloatingOverlayService.ACTION_SHOW
                            putExtra("isTranslating", isTranslating)
                            putExtra("isPaused", isPaused)
                            putExtra("targetLang", targetLang)
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
                        val intent = Intent(this, FloatingOverlayService::class.java).apply {
                            action = FloatingOverlayService.ACTION_UPDATE
                            putExtra("isTranslating", isTranslating)
                            putExtra("isPaused", isPaused)
                            putExtra("targetLang", targetLang)
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
        val pipelineMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_PIPELINE_CHANNEL)
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

        pipelineMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestInternalAudioPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (mediaProjection != null) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        try {
                            mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
                            if (mediaProjectionManager != null) {
                                pendingProjectionResult = result
                                startActivityForResult(
                                    mediaProjectionManager!!.createScreenCaptureIntent(),
                                    REQUEST_MEDIA_PROJECTION
                                )
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Error requesting MediaProjection", e)
                            result.success(false)
                        }
                    } else {
                        // Android 9 or lower does not support internal audio capture
                        result.success(false)
                    }
                }
                "startAudioCapture" -> {
                    val mode = call.argument<String>("mode") ?: "internal"
                    val captureStatus = startRecording(mode)
                    result.success(captureStatus)
                }
                "startMicCapture" -> {
                    val captureStatus = startRecording("internal")
                    result.success(captureStatus["started"] as? Boolean ?: false)
                }
                "stopMicCapture" -> {
                    stopRecording()
                    result.success(true)
                }
                "playPcmChunk" -> {
                    val base64Data = call.argument<String>("data") ?: ""
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    playPcm(base64Data, sampleRate)
                    result.success(true)
                }
                "stopAudioPlayback" -> {
                    stopPlayback()
                    result.success(true)
                }
                "setDubbedVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    currentDubbedVolume = vol
                    try {
                        audioTrack?.setVolume(vol)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error setting audioTrack volume", e)
                    }
                    result.success(true)
                }
                "setOriginalVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                    try {
                        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                        if (audioMgr != null) {
                            val maxVol = audioMgr.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                            val target = (vol * maxVol).toInt().coerceIn(0, maxVol)
                            audioMgr.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, target, 0)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error setting stream volume", e)
                    }
                    result.success(true)
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
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                            override fun onStop() {
                                mediaProjection = null
                            }
                        }, null)
                        pendingProjectionResult?.success(true)
                    } else {
                        pendingProjectionResult?.success(false)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to obtain MediaProjection", e)
                    pendingProjectionResult?.success(false)
                }
            } else {
                pendingProjectionResult?.success(false)
            }
            pendingProjectionResult = null
        }
    }

    private val AUDIO_PIPELINE_CHANNEL = "com.syncdub.livedub/audio_pipeline"
    private val MIC_STREAM_CHANNEL = "com.syncdub.livedub/mic_stream"
    private var micEventSink: io.flutter.plugin.common.EventChannel.EventSink? = null

    private var audioRecord: AudioRecord? = null
    private val isRecording = java.util.concurrent.atomic.AtomicBoolean(false)
    private var recordThread: Thread? = null

    private var audioTrack: android.media.AudioTrack? = null
    private var currentTrackSampleRate = 24000
    private var currentDubbedVolume = 0.85f

    // Non-blocking asynchronous playback queue for 24kHz Gemini speech audio
    private val playbackQueue = java.util.concurrent.LinkedBlockingQueue<ByteArray>()
    private val isPlaying = java.util.concurrent.atomic.AtomicBoolean(false)
    private var playbackThread: Thread? = null

    private fun ensureAudioTrack(sampleRate: Int) {
        if (audioTrack == null || currentTrackSampleRate != sampleRate) {
            try {
                audioTrack?.stop()
                audioTrack?.release()
            } catch (_: Exception) {}

            val minBuf = android.media.AudioTrack.getMinBufferSize(
                sampleRate,
                android.media.AudioFormat.CHANNEL_OUT_MONO,
                android.media.AudioFormat.ENCODING_PCM_16BIT
            )
            // 4x min buffer or 64KB for smooth, stutter-free 24kHz speech output
            val bufferSize = Math.max(minBuf * 4, 65536)

            audioTrack = android.media.AudioTrack.Builder()
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
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
                .build()

            audioTrack?.setVolume(currentDubbedVolume)
            audioTrack?.play()
            currentTrackSampleRate = sampleRate
            android.util.Log.i("MainActivity", "AudioTrack initialized: sampleRate=$sampleRate, bufferSize=$bufferSize")
        }
    }

    private fun startPlaybackWorker() {
        if (isPlaying.get() && playbackThread != null && playbackThread!!.isAlive) return

        isPlaying.set(true)
        playbackThread = Thread {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
            while (isPlaying.get()) {
                try {
                    val chunk = playbackQueue.poll(100, java.util.concurrent.TimeUnit.MILLISECONDS)
                    if (chunk != null && chunk.isNotEmpty()) {
                        audioTrack?.write(chunk, 0, chunk.size)
                    }
                } catch (_: InterruptedException) {
                    break
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error in AudioTrack playback worker", e)
                }
            }
        }.apply {
            name = "SyncDubAudioTrackPlaybackThread"
            start()
        }
    }

    private fun startRecording(preferredMode: String = "internal"): Map<String, Any> {
        if (isRecording.get()) {
            return mapOf("started" to true, "mode" to currentCaptureMode)
        }
        try {
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = Math.max(minBufferSize * 2, 8192)

            var usedInternal = false

            // Android 10+ (API 29+) AudioPlaybackCapture for Direct Internal Video Audio Capture!
            if (preferredMode == "internal" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && mediaProjection != null) {
                try {
                    val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                        .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                        .addMatchingUsage(AudioAttributes.USAGE_GAME)
                        .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                        .build()

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
                            android.util.Log.w("MainActivity", "Internal AudioPlaybackCapture startRecording failed ($startErr), falling back to physical MIC", startErr)
                            try {
                                audioRecord?.stop()
                                audioRecord?.release()
                            } catch (_: Exception) {}
                            audioRecord = null
                            mediaProjection = null
                            usedInternal = false
                        }
                    } else {
                        android.util.Log.w("MainActivity", "AudioPlaybackCapture uninitialized, falling back to MIC")
                        mediaProjection = null
                    }
                } catch (e: Exception) {
                    android.util.Log.w("MainActivity", "Internal audio playback capture setup failed, falling back to MIC", e)
                    mediaProjection = null
                    usedInternal = false
                }
            }

            if (!usedInternal) {
                // Fallback to Physical Microphone Loopback
                audioRecord = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    channelConfig,
                    audioFormat,
                    bufferSize
                )
                if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                    android.util.Log.e("MainActivity", "Physical MIC AudioRecord initialization failed (state=${audioRecord?.state})")
                    return mapOf("started" to false, "mode" to "none", "error" to "AudioRecord uninitialized")
                }
                audioRecord?.startRecording()
                currentCaptureMode = "mic"
                android.util.Log.i("MainActivity", "Physical MIC AudioRecord started successfully")
            }

            isRecording.set(true)
            android.util.Log.i("MainActivity", "AudioRecord successfully active in $currentCaptureMode mode (bufferSize=$bufferSize)")

            recordThread = Thread {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
                // 1600 samples = 3200 bytes = 100ms of 16kHz 16-bit mono audio
                val pcmBuffer = ByteArray(3200)
                while (isRecording.get()) {
                    val read = audioRecord?.read(pcmBuffer, 0, pcmBuffer.size) ?: 0
                    if (read > 0) {
                        // Calculate RMS Amplitude
                        var sum = 0.0
                        for (i in 0 until read step 2) {
                            val sample = ((pcmBuffer[i + 1].toInt() shl 8) or (pcmBuffer[i].toInt() and 0xFF)).toShort()
                            sum += sample * sample
                        }
                        val rms = Math.sqrt(sum / (read / 2.0))
                        val normalizedAmp = (rms / 32768.0).coerceIn(0.0, 1.0)

                        val base64Data = android.util.Base64.encodeToString(pcmBuffer, 0, read, android.util.Base64.NO_WRAP)
                        val eventData = mapOf(
                            "pcm" to base64Data,
                            "amp" to normalizedAmp,
                            "bytes" to read,
                            "mode" to currentCaptureMode
                        )

                        runOnUiThread {
                            micEventSink?.success(eventData)
                        }
                    }
                }
            }.apply {
                name = "SyncDubAudioRecordThread"
                start()
            }
            return mapOf("started" to true, "mode" to currentCaptureMode)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start AudioRecord", e)
            return mapOf("started" to false, "mode" to "none", "error" to (e.message ?: ""))
        }
    }

    private fun stopRecording() {
        isRecording.set(false)
        try {
            recordThread?.interrupt()
            recordThread = null
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            android.util.Log.i("MainActivity", "AudioRecord stopped")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping AudioRecord", e)
        }
    }

    private fun playPcm(base64Data: String, sampleRate: Int) {
        if (base64Data.isEmpty()) return
        try {
            val bytes = android.util.Base64.decode(base64Data, android.util.Base64.DEFAULT)
            ensureAudioTrack(sampleRate)
            startPlaybackWorker()
            playbackQueue.offer(bytes)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error queueing PCM audio chunk", e)
        }
    }

    private fun stopPlayback() {
        isPlaying.set(false)
        playbackQueue.clear()
        try {
            playbackThread?.interrupt()
            playbackThread = null
            audioTrack?.stop()
            audioTrack?.flush()
            audioTrack?.release()
            audioTrack = null
            android.util.Log.i("MainActivity", "AudioTrack stopped & released")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping AudioTrack", e)
        }
    }

    override fun onDestroy() {
        stopRecording()
        stopPlayback()
        super.onDestroy()
    }
}
