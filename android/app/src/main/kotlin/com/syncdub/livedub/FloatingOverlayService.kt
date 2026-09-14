package com.syncdub.livedub

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FloatingOverlayService : Service() {

    companion object {
        const val ACTION_SHOW = "com.syncdub.livedub.ACTION_SHOW"
        const val ACTION_UPDATE = "com.syncdub.livedub.ACTION_UPDATE"
        const val ACTION_HIDE = "com.syncdub.livedub.ACTION_HIDE"
        const val ACTION_TOGGLE_PAUSE = "com.syncdub.livedub.ACTION_TOGGLE_PAUSE"

        private const val CHANNEL_ID = "syncdub_live_service_channel"
        private const val NOTIFICATION_ID = 1001
        var isServiceRunning = false
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var rootParams: WindowManager.LayoutParams? = null

    private var isTranslating = false
    private var isPaused = false
    private var targetLang = "HI"

    private var isExpanded = false
    private var isDocked = false

    private var statusDot: View? = null
    private var controlsContainer: LinearLayout? = null
    private var pauseBtn: TextView? = null
    private var langBtn: TextView? = null

    private var wakeLock: PowerManager.WakeLock? = null

    // 10-second inactivity timer to auto-dock to screen edge
    private val inactivityHandler = Handler(Looper.getMainLooper())
    private val autoDockRunnable = Runnable {
        autoDockToSide()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                wakeLock = powerManager?.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "SyncDubAI:LiveDubbingWakeLock"
                )?.apply {
                    setReferenceCounted(false)
                    acquire(2 * 60 * 60 * 1000L) // 2 hours max safety timeout
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("FloatingOverlay", "Failed to acquire wake lock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        wakeLock = null
    }

    private fun resetInactivityTimer() {
        inactivityHandler.removeCallbacks(autoDockRunnable)
        inactivityHandler.postDelayed(autoDockRunnable, 10_000L) // 10 seconds
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_SHOW -> {
                isTranslating = intent.getBooleanExtra("isTranslating", true)
                isPaused = intent.getBooleanExtra("isPaused", false)
                targetLang = intent.getStringExtra("targetLang") ?: targetLang
                startForegroundServiceCompat()
                acquireWakeLock()
                if (overlayView == null) {
                    createOverlayView()
                } else {
                    updateOverlayUI()
                }
                resetInactivityTimer()
            }
            ACTION_UPDATE -> {
                isTranslating = intent.getBooleanExtra("isTranslating", isTranslating)
                isPaused = intent.getBooleanExtra("isPaused", isPaused)
                targetLang = intent.getStringExtra("targetLang") ?: targetLang
                startForegroundServiceCompat()
                updateOverlayUI()
                resetInactivityTimer()
            }
            ACTION_TOGGLE_PAUSE -> {
                isPaused = !isPaused
                updateOverlayUI()
                MainActivity.triggerPauseResume()
                startForegroundServiceCompat()
                resetInactivityTimer()
            }
            ACTION_HIDE -> {
                inactivityHandler.removeCallbacks(autoDockRunnable)
                releaseWakeLock()
                removeOverlayView()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SyncDub AI Live Dubbing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SyncDub real-time translation and microphone audio active in background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun startForegroundServiceCompat() {
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                } else {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                startForeground(NOTIFICATION_ID, notification, serviceType)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (_: Exception) {}
        }
    }

    private fun buildNotification(): Notification {
        val appIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val pauseIntent = Intent(this, FloatingOverlayService::class.java).apply {
            action = ACTION_TOGGLE_PAUSE
        }
        val pausePendingIntent = PendingIntent.getService(
            this,
            1,
            pauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, FloatingOverlayService::class.java).apply {
            action = ACTION_HIDE
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = "SyncDub AI · Live Real-Time Dubbing"
        val statusText = if (isPaused) {
            "Translation Paused · Tap to resume"
        } else {
            "Real-time audio streaming & dubbing active in background ($targetLang)"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(statusText)
            .setOngoing(true)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                0,
                if (isPaused) "▶ Resume" else "⏸ Pause",
                pausePendingIntent
            )
            .addAction(
                0,
                "⏹ Stop",
                stopPendingIntent
            )
            .build()
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createOverlayView() {
        if (overlayView != null) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            return
        }

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val bubbleSize = dpToPx(52f)
        val params = WindowManager.LayoutParams(
            bubbleSize,
            bubbleSize,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dpToPx(16f)
            y = dpToPx(200f)
        }
        rootParams = params

        // Root horizontal container holding [Bubble Icon] + [Expanded Controls Capsule]
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // 1. Bubble Layout (52dp x 52dp)
        val bubbleLayout = FrameLayout(this).apply {
            val bubbleParams = LinearLayout.LayoutParams(bubbleSize, bubbleSize)
            layoutParams = bubbleParams
            elevation = dpToPx(8f).toFloat()
        }

        // Full uncropped user image inside bubble
        val appIconView = ImageView(this).apply {
            setImageResource(R.drawable.ic_floating_icon)
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        bubbleLayout.addView(appIconView)

        // Status Indicator Dot (Emerald for live, Amber for paused)
        statusDot = View(this).apply {
            val dotSize = dpToPx(12f)
            val dotParams = FrameLayout.LayoutParams(dotSize, dotSize).apply {
                gravity = Gravity.BOTTOM or Gravity.END
                setMargins(0, 0, dpToPx(2f), dpToPx(2f))
            }
            layoutParams = dotParams
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(if (isPaused) Color.parseColor("#F59E0B") else Color.parseColor("#10B981"))
                setStroke(dpToPx(1.5f), Color.WHITE)
            }
        }
        bubbleLayout.addView(statusDot)
        rootLayout.addView(bubbleLayout)

        // 2. Controls Container Capsule (Shows Pause/Resume, Language, and Open App)
        controlsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            visibility = View.GONE
            val capsuleParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(44f)
            ).apply {
                marginStart = dpToPx(8f)
            }
            layoutParams = capsuleParams
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(22f).toFloat()
                setColor(Color.parseColor("#0F172A")) // Deep dark slate
                setStroke(dpToPx(1f), Color.parseColor("#334155")) // Subtle slate border
            }
            setPadding(dpToPx(6f), dpToPx(4f), dpToPx(8f), dpToPx(4f))
            elevation = dpToPx(10f).toFloat()
        }

        // 2a. Pause / Resume Button
        pauseBtn = TextView(this).apply {
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(34f)
            )
            layoutParams = btnParams
            gravity = Gravity.CENTER
            setPadding(dpToPx(12f), 0, dpToPx(12f), 0)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, Typeface.BOLD)
            updatePauseBtnUI()
            setOnClickListener {
                resetInactivityTimer()
                isPaused = !isPaused
                MainActivity.triggerPauseResume()
                updateOverlayUI()
            }
        }
        controlsContainer?.addView(pauseBtn)

        // 2b. Language Button (🌐 HI / ES / EN)
        langBtn = TextView(this).apply {
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(34f)
            ).apply {
                marginStart = dpToPx(6f)
            }
            layoutParams = btnParams
            gravity = Gravity.CENTER
            setPadding(dpToPx(10f), 0, dpToPx(10f), 0)
            text = "🌐 $targetLang"
            setTextColor(Color.parseColor("#38BDF8")) // Sky blue
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTypeface(typeface, Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(17f).toFloat()
                setColor(Color.parseColor("#1E293B"))
                setStroke(dpToPx(1f), Color.parseColor("#475569"))
            }
            setOnClickListener {
                resetInactivityTimer()
                MainActivity.triggerLanguageCycle()
            }
        }
        controlsContainer?.addView(langBtn)

        // 2c. Open App Button (⤢)
        val appBtn = TextView(this).apply {
            val btnParams = LinearLayout.LayoutParams(
                dpToPx(34f),
                dpToPx(34f)
            ).apply {
                marginStart = dpToPx(6f)
            }
            layoutParams = btnParams
            gravity = Gravity.CENTER
            text = "⤢"
            setTextColor(Color.parseColor("#F1F5F9"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(17f).toFloat()
                setColor(Color.parseColor("#1E293B"))
                setStroke(dpToPx(1f), Color.parseColor("#475569"))
            }
            setOnClickListener {
                resetInactivityTimer()
                openMainActivity()
            }
        }
        controlsContainer?.addView(appBtn)

        rootLayout.addView(controlsContainer)

        // Touch & Drag Listener on the Icon Bubble
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isMoving = false

        bubbleLayout.setOnTouchListener { _, event ->
            resetInactivityTimer()
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isMoving = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) {
                        isMoving = true
                    }
                    if (isMoving) {
                        val screenWidth = resources.displayMetrics.widthPixels
                        val screenHeight = resources.displayMetrics.heightPixels
                        params.x = (initialX + dx).coerceIn(0, screenWidth - bubbleSize)
                        params.y = (initialY + dy).coerceIn(0, screenHeight - bubbleSize)
                        try {
                            windowManager?.updateViewLayout(rootLayout, params)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isMoving) {
                        // User tapped on the bubble icon -> toggle controls / undock
                        onBubbleTapped()
                    } else {
                        isDocked = false
                    }
                    true
                }
                else -> false
            }
        }

        overlayView = rootLayout
        try {
            windowManager?.addView(overlayView, params)
            isServiceRunning = true
            resetInactivityTimer()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun onBubbleTapped() {
        val screenWidth = resources.displayMetrics.widthPixels
        val bubbleSize = dpToPx(52f)

        if (isDocked) {
            // Undock from the screen edge
            isDocked = false
            val isLeft = (rootParams?.x ?: 0) < (screenWidth / 2)
            rootParams?.x = if (isLeft) dpToPx(16f) else screenWidth - dpToPx(240f)
            isExpanded = true
        } else {
            // Toggle expanded controls
            isExpanded = !isExpanded
        }

        updateControlsVisibility()
    }

    private fun updateControlsVisibility() {
        val params = rootParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val bubbleSize = dpToPx(52f)

        if (isExpanded) {
            controlsContainer?.visibility = View.VISIBLE
            params.width = WindowManager.LayoutParams.WRAP_CONTENT
            // Keep on screen if near right edge
            val approxWidth = dpToPx(240f)
            if (params.x + approxWidth > screenWidth) {
                params.x = (screenWidth - approxWidth - dpToPx(12f)).coerceAtLeast(0)
            }
        } else {
            controlsContainer?.visibility = View.GONE
            params.width = bubbleSize
        }

        try {
            windowManager?.updateViewLayout(overlayView, params)
        } catch (_: Exception) {}
    }

    private fun autoDockToSide() {
        val params = rootParams ?: return
        if (overlayView == null) return

        try {
            isExpanded = false
            controlsContainer?.visibility = View.GONE

            val screenWidth = resources.displayMetrics.widthPixels
            val bubbleSize = dpToPx(52f)
            val dockLeft = params.x < (screenWidth / 2)

            isDocked = true
            // Snap tightly to the edge so user's content is not obstructed
            params.x = if (dockLeft) -dpToPx(14f) else screenWidth - bubbleSize + dpToPx(14f)
            params.width = bubbleSize

            windowManager?.updateViewLayout(overlayView, params)
        } catch (e: Exception) {
            android.util.Log.e("FloatingOverlay", "Error auto-docking", e)
        }
    }

    private fun updatePauseBtnUI() {
        pauseBtn?.apply {
            if (isPaused) {
                text = "▶ Resume"
                setTextColor(Color.parseColor("#34D399")) // Emerald
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(17f).toFloat()
                    setColor(Color.parseColor("#064E3B")) // Emerald dark bg
                    setStroke(dpToPx(1f), Color.parseColor("#059669"))
                }
            } else {
                text = "⏸ Pause"
                setTextColor(Color.parseColor("#FBBF24")) // Amber
                background = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = dpToPx(17f).toFloat()
                    setColor(Color.parseColor("#78350F")) // Amber dark bg
                    setStroke(dpToPx(1f), Color.parseColor("#D97706"))
                }
            }
        }
    }

    private fun openMainActivity() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
    }

    private fun updateOverlayUI() {
        if (overlayView == null) return

        statusDot?.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(if (isPaused) Color.parseColor("#F59E0B") else Color.parseColor("#10B981"))
            setStroke(dpToPx(1.5f), Color.WHITE)
        }

        updatePauseBtnUI()
        langBtn?.text = "🌐 $targetLang"
    }

    private fun removeOverlayView() {
        inactivityHandler.removeCallbacks(autoDockRunnable)
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {}
            overlayView = null
            isServiceRunning = false
        }
    }

    override fun onDestroy() {
        inactivityHandler.removeCallbacks(autoDockRunnable)
        releaseWakeLock()
        removeOverlayView()
        super.onDestroy()
    }
}
