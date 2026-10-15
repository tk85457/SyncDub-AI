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
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.app.NotificationCompat

data class OverlayLang(
    val code: String,
    val name: String,
    val flag: String,
    val abbr: String
)

class FloatingOverlayService : Service() {

    companion object {
        const val ACTION_START_FOREGROUND = "com.syncdub.livedub.ACTION_START_FOREGROUND"
        const val ACTION_SHOW = "com.syncdub.livedub.ACTION_SHOW"
        const val ACTION_UPDATE = "com.syncdub.livedub.ACTION_UPDATE"
        const val ACTION_HIDE = "com.syncdub.livedub.ACTION_HIDE"
        const val ACTION_TOGGLE_PAUSE = "com.syncdub.livedub.ACTION_TOGGLE_PAUSE"
        const val ACTION_STOP_DUBBING = "com.syncdub.livedub.ACTION_STOP_DUBBING"
        const val ACTION_REMOVE_OVERLAY_KEEP = "com.syncdub.livedub.ACTION_REMOVE_OVERLAY_KEEP"
        const val ACTION_ENSURE_FOREGROUND = "com.syncdub.livedub.ACTION_ENSURE_FOREGROUND"

        private const val CHANNEL_ID = "syncdub_live_service_channel"
        private const val NOTIFICATION_ID = 1001
        var instance: FloatingOverlayService? = null
        var isServiceRunning = false
        var isForegroundActive = false
        var onForegroundReadyListener: (() -> Unit)? = null

        fun promoteToMediaProjection() {
            instance?.upgradeToMediaProjectionForeground()
        }

        fun demoteFromMediaProjection() {
            instance?.downgradeFromMediaProjectionForeground()
        }

        // All 71 languages supported in the SyncDub Chrome extension
        val OVERLAY_LANGUAGES = listOf(
            // South Asian (15)
            OverlayLang("hi", "Hindi", "🇮🇳", "HI"),
            OverlayLang("en", "English", "🇺🇸", "EN"),
            OverlayLang("bn", "Bengali", "🇮🇳", "BN"),
            OverlayLang("ta", "Tamil", "🇮🇳", "TA"),
            OverlayLang("te", "Telugu", "🇮🇳", "TE"),
            OverlayLang("mr", "Marathi", "🇮🇳", "MR"),
            OverlayLang("gu", "Gujarati", "🇮🇳", "GU"),
            OverlayLang("kn", "Kannada", "🇮🇳", "KN"),
            OverlayLang("ml", "Malayalam", "🇮🇳", "ML"),
            OverlayLang("pa", "Punjabi", "🇮🇳", "PA"),
            OverlayLang("or", "Odia", "🇮🇳", "OR"),
            OverlayLang("as", "Assamese", "🇮🇳", "AS"),
            OverlayLang("ur", "Urdu", "🇵🇰", "UR"),
            OverlayLang("ne", "Nepali", "🇳🇵", "NE"),
            OverlayLang("si", "Sinhala", "🇱🇰", "SI"),

            // East Asian (5)
            OverlayLang("ja", "Japanese", "🇯🇵", "JA"),
            OverlayLang("zh-CN", "Chinese (Simplified)", "🇨🇳", "ZH"),
            OverlayLang("zh-TW", "Chinese (Traditional)", "🇹🇼", "ZHT"),
            OverlayLang("ko", "Korean", "🇰🇷", "KO"),
            OverlayLang("mn", "Mongolian", "🇲🇳", "MN"),

            // Southeast Asian (8)
            OverlayLang("vi", "Vietnamese", "🇻🇳", "VI"),
            OverlayLang("th", "Thai", "🇹🇭", "TH"),
            OverlayLang("id", "Indonesian", "🇮🇩", "ID"),
            OverlayLang("ms", "Malay", "🇲🇾", "MS"),
            OverlayLang("fil", "Filipino", "🇵🇭", "FIL"),
            OverlayLang("km", "Khmer", "🇰🇭", "KM"),
            OverlayLang("my", "Burmese", "🇲🇲", "MY"),
            OverlayLang("lo", "Lao", "🇱🇦", "LO"),

            // European - Romance (7)
            OverlayLang("es", "Spanish", "🇪🇸", "ES"),
            OverlayLang("fr", "French", "🇫🇷", "FR"),
            OverlayLang("pt", "Portuguese", "🇧🇷", "PT"),
            OverlayLang("it", "Italian", "🇮🇹", "IT"),
            OverlayLang("ro", "Romanian", "🇷🇴", "RO"),
            OverlayLang("ca", "Catalan", "🇪🇸", "CA"),
            OverlayLang("gl", "Galician", "🇪🇸", "GL"),

            // European - Germanic (6)
            OverlayLang("de", "German", "🇩🇪", "DE"),
            OverlayLang("nl", "Dutch", "🇳🇱", "NL"),
            OverlayLang("sv", "Swedish", "🇸🇪", "SV"),
            OverlayLang("no", "Norwegian", "🇳🇴", "NO"),
            OverlayLang("da", "Danish", "🇩🇰", "DA"),
            OverlayLang("is", "Icelandic", "🇮🇸", "IS"),

            // Slavic (11)
            OverlayLang("ru", "Russian", "🇷🇺", "RU"),
            OverlayLang("uk", "Ukrainian", "🇺🇦", "UK"),
            OverlayLang("pl", "Polish", "🇵🇱", "PL"),
            OverlayLang("cs", "Czech", "🇨🇿", "CS"),
            OverlayLang("sk", "Slovak", "🇸🇰", "SK"),
            OverlayLang("hr", "Croatian", "🇭🇷", "HR"),
            OverlayLang("sr", "Serbian", "🇷🇸", "SR"),
            OverlayLang("bg", "Bulgarian", "🇧🇬", "BG"),
            OverlayLang("sl", "Slovenian", "🇸🇮", "SL"),
            OverlayLang("bs", "Bosnian", "🇧🇦", "BS"),
            OverlayLang("mk", "Macedonian", "🇲🇰", "MK"),

            // European - Other (8)
            OverlayLang("fi", "Finnish", "🇫🇮", "FI"),
            OverlayLang("hu", "Hungarian", "🇭🇺", "HU"),
            OverlayLang("el", "Greek", "🇬🇷", "EL"),
            OverlayLang("et", "Estonian", "🇪🇪", "ET"),
            OverlayLang("lv", "Latvian", "🇱🇻", "LV"),
            OverlayLang("lt", "Lithuanian", "🇱🇹", "LT"),
            OverlayLang("sq", "Albanian", "🇦🇱", "SQ"),
            OverlayLang("mt", "Maltese", "🇲🇹", "MT"),

            // Celtic (2)
            OverlayLang("cy", "Welsh", "🏴󠁧󠁢󠁷󠁬󠁳󠁿", "CY"),
            OverlayLang("ga", "Irish", "🇮🇪", "GA"),

            // Turkic (4)
            OverlayLang("tr", "Turkish", "🇹🇷", "TR"),
            OverlayLang("az", "Azerbaijani", "🇦🇿", "AZ"),
            OverlayLang("kk", "Kazakh", "🇰🇿", "KK"),
            OverlayLang("uz", "Uzbek", "🇺🇿", "UZ"),

            // Middle East (3)
            OverlayLang("ar", "Arabic", "🇸🇦", "AR"),
            OverlayLang("he", "Hebrew", "🇮🇱", "HE"),
            OverlayLang("fa", "Persian", "🇮🇷", "FA"),

            // Caucasus (2)
            OverlayLang("ka", "Georgian", "🇬🇪", "KA"),
            OverlayLang("hy", "Armenian", "🇦🇲", "HY"),

            // African (8)
            OverlayLang("sw", "Swahili", "🇰🇪", "SW"),
            OverlayLang("af", "Afrikaans", "🇿🇦", "AF"),
            OverlayLang("am", "Amharic", "🇪🇹", "AM"),
            OverlayLang("yo", "Yoruba", "🇳🇬", "YO"),
            OverlayLang("ig", "Igbo", "🇳🇬", "IG"),
            OverlayLang("ha", "Hausa", "🇳🇬", "HA"),
            OverlayLang("zu", "Zulu", "🇿🇦", "ZU"),
            OverlayLang("xh", "Xhosa", "🇿🇦", "XH"),

            // Basque (1)
            OverlayLang("eu", "Basque", "🇪🇸", "EU")
        )
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var rootParams: WindowManager.LayoutParams? = null

    // Language Picker Dialog Window
    private var langDialogView: View? = null

    private var isTranslating = false
    private var isPaused = false
    private var lastPauseToggleTime = 0L
    private var targetLang = "HI"
    private var targetLangFlag = "🇮🇳"
    private var targetLangName = "Hindi"

    private var isExpanded = true
    private var isDocked = false

    private var capsuleLayout: LinearLayout? = null
    private var iconContainerView: FrameLayout? = null
    private var statusDot: View? = null
    private var pauseBtn: ImageView? = null
    private var langBtn: TextView? = null
    private var appBtn: ImageView? = null

    private var wakeLock: PowerManager.WakeLock? = null

    // 4-second inactivity timer to auto-dock to screen edge without disturbing user (3-5s range)
    private val inactivityHandler = Handler(Looper.getMainLooper())
    private val autoDockRunnable = Runnable {
        collapseToDockedIcon()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private var hasMediaProjectionPermission = false

    fun upgradeToMediaProjectionForeground() {
        hasMediaProjectionPermission = true
        startForegroundServiceCompat()
    }

    fun downgradeFromMediaProjectionForeground() {
        hasMediaProjectionPermission = false
        if (isTranslating) {
            startForegroundServiceCompat()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
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
        inactivityHandler.postDelayed(autoDockRunnable, 4_000L) // 4 seconds (3-5s range)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            // System restart after the process was killed: the dubbing session is gone, nothing to keep alive
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_START_FOREGROUND -> {
                // Starts background foreground service with notification for MediaProjection/Microphone,
                // but DOES NOT display any floating overlay on the screen!
                if (intent.hasExtra("hasMediaProjection")) {
                    hasMediaProjectionPermission = intent.getBooleanExtra("hasMediaProjection", false)
                }
                startForegroundServiceCompat()
                acquireWakeLock()
            }
            ACTION_SHOW -> {
                isTranslating = intent.getBooleanExtra("isTranslating", false)
                isPaused = intent.getBooleanExtra("isPaused", false)
                targetLang = intent.getStringExtra("targetLang") ?: targetLang
                targetLangFlag = intent.getStringExtra("targetLangFlag") ?: targetLangFlag
                targetLangName = intent.getStringExtra("targetLangName") ?: targetLangName
                syncLanguageDetails()
                isExpanded = true
                isDocked = false
                if (isTranslating) {
                    startForegroundServiceCompat()
                    acquireWakeLock()
                    if (overlayView == null) {
                        createOverlayView()
                    } else {
                        expandFullCapsule()
                        updateOverlayUI()
                        updateControlsVisibility()
                    }
                    resetInactivityTimer()
                } else {
                    startForegroundServiceCompat()
                    inactivityHandler.removeCallbacks(autoDockRunnable)
                    releaseWakeLock()
                    dismissLanguagePickerDialog()
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
            ACTION_UPDATE -> {
                isTranslating = intent.getBooleanExtra("isTranslating", isTranslating)
                isPaused = intent.getBooleanExtra("isPaused", isPaused)
                targetLang = intent.getStringExtra("targetLang") ?: targetLang
                targetLangFlag = intent.getStringExtra("targetLangFlag") ?: targetLangFlag
                targetLangName = intent.getStringExtra("targetLangName") ?: targetLangName
                syncLanguageDetails()
                if (isTranslating) {
                    startForegroundServiceCompat()
                    updateOverlayUI()
                    resetInactivityTimer()
                } else {
                    startForegroundServiceCompat()
                    inactivityHandler.removeCallbacks(autoDockRunnable)
                    releaseWakeLock()
                    dismissLanguagePickerDialog()
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
            ACTION_TOGGLE_PAUSE -> {
                val now = System.currentTimeMillis()
                if (now - lastPauseToggleTime > 350) {
                    lastPauseToggleTime = now
                    isPaused = !isPaused
                    updateOverlayUI()
                    MainActivity.nativePauseHint(isPaused)
                    MainActivity.triggerPauseResume()
                    if (isTranslating) {
                        startForegroundServiceCompat()
                    }
                    resetInactivityTimer()
                }
            }
            ACTION_STOP_DUBBING -> {
                // Notification "Stop": the live WebSocket + audio capture live in Flutter/MainActivity,
                // so Flutter must be told to end the session (previously only the bubble disappeared
                // and dubbing silently kept running with no UI).
                isTranslating = false
                MainActivity.triggerStopDubbing()
                inactivityHandler.removeCallbacks(autoDockRunnable)
                releaseWakeLock()
                dismissLanguagePickerDialog()
                removeOverlayView()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
            ACTION_REMOVE_OVERLAY_KEEP -> {
                // Bubble disabled by user while dubbing: drop only the window, keep foreground + wakelock
                inactivityHandler.removeCallbacks(autoDockRunnable)
                dismissLanguagePickerDialog()
                removeOverlayView()
                startForegroundServiceCompat()
                acquireWakeLock()
            }
            ACTION_ENSURE_FOREGROUND -> {
                startForegroundServiceCompat()
                acquireWakeLock()
            }
            ACTION_HIDE -> {
                inactivityHandler.removeCallbacks(autoDockRunnable)
                releaseWakeLock()
                dismissLanguagePickerDialog()
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
        return START_NOT_STICKY // a live session cannot be revived by the system after a kill
    }

    private fun syncLanguageDetails() {
        val matched = OVERLAY_LANGUAGES.find {
            it.abbr.equals(targetLang, ignoreCase = true) ||
            it.code.equals(targetLang, ignoreCase = true)
        }
        if (matched != null) {
            targetLang = matched.abbr
            targetLangFlag = matched.flag
            targetLangName = matched.name
        }
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
                var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                                  ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                if (hasMediaProjectionPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                }
                startForeground(NOTIFICATION_ID, notification, serviceType)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            isForegroundActive = true
            onForegroundReadyListener?.invoke()
        } catch (e: Exception) {
            android.util.Log.e("FloatingOverlay", "startForegroundServiceCompat error", e)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    try {
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                    } catch (_: Exception) {
                        // RECORD_AUDIO not granted yet (Android 14 rejects the microphone type) -> still become foreground
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                    }
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                isForegroundActive = true
                onForegroundReadyListener?.invoke()
            } catch (_: Exception) {}
        }
    }

    private fun buildNotification(): Notification {
        val appIntent = (packageManager.getLaunchIntentForPackage(packageName) ?: Intent()).apply {
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
            action = ACTION_STOP_DUBBING
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Clean, short copy: what is happening + which language. No emoji glyphs in the status bar.
        val title = if (isPaused) "SyncDub paused" else "SyncDub is dubbing live"
        val statusText = if (isPaused) {
            "$targetLangName \u00B7 Tap Resume to continue"
        } else {
            "Translating to $targetLangName in real time"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_syncdub) // monochrome waveform (the colour launcher icon turned into a white blob)
            .setColor(Color.parseColor("#10B981"))
            .setContentTitle(title)
            .setContentText(statusText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(contentPendingIntent)
            .addAction(0, if (isPaused) "Resume" else "Pause", pausePendingIntent)
            .addAction(0, "Stop", stopPendingIntent)
            .build()
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    // ---- Design tokens: one dark surface, white-12% buttons, emerald = live, amber = paused ----
    private val colSurface = Color.parseColor("#F2111827")
    private val colStroke = Color.parseColor("#1FFFFFFF")
    private val colButton = Color.parseColor("#1FFFFFFF")
    private val colAvatar = Color.parseColor("#1E293B")
    private val colLive = Color.parseColor("#10B981")
    private val colPaused = Color.parseColor("#F59E0B")
    private val colText = Color.parseColor("#F8FAFC")

    private fun circleBg(color: Int): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
    }

    private fun pillBg(color: Int, radiusDp: Float, strokeColor: Int = Color.TRANSPARENT, strokeDp: Float = 0f): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(radiusDp).toFloat()
            setColor(color)
            if (strokeDp > 0f) setStroke(dpToPx(strokeDp), strokeColor)
        }

    private fun statusRing(): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(Color.TRANSPARENT)
        setStroke(dpToPx(2.5f), if (isPaused) colPaused else colLive)
    }

    private fun iconButton(iconRes: Int, bg: Int, descr: String): ImageView {
        val size = dpToPx(40f)
        return ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(size, size).apply { marginStart = dpToPx(6f) }
            scaleType = ImageView.ScaleType.FIT_CENTER
            val pad = dpToPx(11f)
            setPadding(pad, pad, pad, pad)
            setImageResource(iconRes)
            background = circleBg(bg)
            contentDescription = descr
        }
    }

    private fun dockedWidthPx(): Int = dpToPx(48f)

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

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dpToPx(12f)
            y = dpToPx(140f)
        }
        rootParams = params

        // One rounded pill. Collapsed it is just the round avatar, expanded it shows the controls.
        val capsule = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = pillBg(colSurface, 28f, colStroke, 1f)
            setPadding(dpToPx(4f), dpToPx(4f), dpToPx(4f), dpToPx(4f))
        }
        capsuleLayout = capsule

        // 1. Avatar: round app icon with a status ring (green = live, amber = paused)
        val avatarSize = dpToPx(40f)
        val avatar = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(avatarSize, avatarSize)
            background = circleBg(colAvatar)
        }
        iconContainerView = avatar

        val logo = ImageView(this).apply {
            setImageResource(R.drawable.ic_floating_icon)
            scaleType = ImageView.ScaleType.CENTER_CROP
            val m = dpToPx(3.5f)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ).apply { setMargins(m, m, m, m) }
            clipToOutline = true
            outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: View, outline: android.graphics.Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
        }
        avatar.addView(logo)

        val ring = View(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            background = statusRing()
        }
        statusDot = ring
        avatar.addView(ring)
        capsule.addView(avatar)

        // 2. Pause / Resume icon button
        val pauseView = iconButton(R.drawable.ic_overlay_pause, colButton, "Pause")
        pauseBtn = pauseView
        updatePauseBtnUI(pauseView)
        capsule.addView(pauseView)

        // 3. Language chip
        langBtn = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(40f)
            ).apply { marginStart = dpToPx(6f) }
            gravity = Gravity.CENTER
            setPadding(dpToPx(14f), 0, dpToPx(14f), 0)
            text = "$targetLangFlag  $targetLang"
            setTextColor(colText)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(typeface, Typeface.BOLD)
            background = pillBg(colButton, 20f)
        }
        capsule.addView(langBtn)

        // 4. Open app icon button
        val openView = iconButton(R.drawable.ic_overlay_open, colButton, "Open SyncDub")
        (openView.layoutParams as LinearLayout.LayoutParams).marginEnd = dpToPx(2f)
        appBtn = openView
        capsule.addView(openView)

        // Touch, Drag, and Individual Button Click Handling
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var touchDownTime = 0L
        var isMoving = false
        val scaledTouchSlop = android.view.ViewConfiguration.get(this).scaledTouchSlop

        capsule.setOnTouchListener { _, event ->
            resetInactivityTimer()
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    touchDownTime = System.currentTimeMillis()
                    isMoving = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    val dist = Math.hypot(dx.toDouble(), dy.toDouble())
                    if (dist > scaledTouchSlop) {
                        isMoving = true
                    }
                    if (isMoving) {
                        val screenWidth = resources.displayMetrics.widthPixels
                        val screenHeight = resources.displayMetrics.heightPixels
                        val viewWidth = capsule.width.coerceAtLeast(dockedWidthPx())
                        val viewHeight = capsule.height.coerceAtLeast(dockedWidthPx())
                        params.x = (initialX + dx).coerceIn(0, (screenWidth - viewWidth).coerceAtLeast(0))
                        params.y = (initialY + dy).coerceIn(dpToPx(24f), (screenHeight - viewHeight - dpToPx(24f)).coerceAtLeast(dpToPx(24f)))
                        try {
                            windowManager?.updateViewLayout(capsule, params)
                        } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val duration = System.currentTimeMillis() - touchDownTime
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    val dist = Math.hypot(dx.toDouble(), dy.toDouble())
                    val isClick = !isMoving && duration < 400 && dist < scaledTouchSlop * 1.5

                    if (isMoving) {
                        if (isDocked || !isExpanded) {
                            snapToNearestEdge()
                        }
                    } else if (isClick) {
                        if (isDocked || !isExpanded) {
                            expandFullCapsule()
                        } else {
                            if (isPointInsideView(iconContainerView, event.rawX, event.rawY)) {
                                collapseToDockedIcon()
                            } else if (isPointInsideView(pauseBtn, event.rawX, event.rawY)) {
                                val now = System.currentTimeMillis()
                                if (now - lastPauseToggleTime > 350) {
                                    lastPauseToggleTime = now
                                    isPaused = !isPaused
                                    updateOverlayUI()
                                    MainActivity.nativePauseHint(isPaused)
                                    MainActivity.triggerPauseResume()
                                }
                            } else if (isPointInsideView(langBtn, event.rawX, event.rawY)) {
                                showLanguagePickerDialog()
                            } else if (isPointInsideView(appBtn, event.rawX, event.rawY)) {
                                openMainActivity()
                            } else {
                                collapseToDockedIcon()
                            }
                        }
                    }
                    true
                }
                else -> false
            }
        }

        capsule.alpha = 0f
        capsule.scaleX = 0.85f
        capsule.scaleY = 0.85f
        overlayView = capsule
        try {
            windowManager?.addView(overlayView, params)
            isServiceRunning = true
            capsule.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(180L).start()
            resetInactivityTimer()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun expandFullCapsule() {
        val wasDocked = isDocked
        isDocked = false
        isExpanded = true
        val params = rootParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels

        pauseBtn?.visibility = View.VISIBLE
        langBtn?.visibility = View.VISIBLE
        appBtn?.visibility = View.VISIBLE

        capsuleLayout?.background = pillBg(colSurface, 28f, colStroke, 1f)
        capsuleLayout?.alpha = 1f

        capsuleLayout?.animate()?.cancel()
        capsuleLayout?.alpha = 1f

        val estWidth = dpToPx(236f)
        val target = if (wasDocked) {
            if (params.x < screenWidth / 2) dpToPx(8f)
            else (screenWidth - estWidth - dpToPx(8f)).coerceAtLeast(dpToPx(8f))
        } else if (params.x + estWidth > screenWidth) {
            (screenWidth - estWidth - dpToPx(8f)).coerceAtLeast(dpToPx(8f))
        } else if (params.x < dpToPx(8f)) {
            dpToPx(8f)
        } else {
            params.x
        }
        animateOverlayX(target)

        resetInactivityTimer()
    }

    private fun updateControlsVisibility() {
        val params = rootParams ?: return
        val vis = if (isExpanded) View.VISIBLE else View.GONE
        pauseBtn?.visibility = vis
        langBtn?.visibility = vis
        appBtn?.visibility = vis
        capsuleLayout?.alpha = if (isExpanded) 1f else 0.8f
        try {
            windowManager?.updateViewLayout(overlayView, params)
        } catch (_: Exception) {}
    }

    private var dockAnimator: android.animation.ValueAnimator? = null

    /** Smoothly slides the overlay window horizontally (used for docking / undocking). */
    private fun animateOverlayX(toX: Int, durationMs: Long = 220L) {
        val params = rootParams ?: return
        val view = overlayView ?: return
        dockAnimator?.cancel()
        val from = params.x
        if (from == toX) return
        dockAnimator = android.animation.ValueAnimator.ofInt(from, toX).apply {
            duration = durationMs
            interpolator = android.view.animation.DecelerateInterpolator()
            addUpdateListener { anim ->
                params.x = anim.animatedValue as Int
                try {
                    windowManager?.updateViewLayout(view, params)
                } catch (_: Exception) {
                    cancel()
                }
            }
            start()
        }
    }

    private fun isDockLeft(params: WindowManager.LayoutParams): Boolean {
        val screenWidth = resources.displayMetrics.widthPixels
        val width = (capsuleLayout?.width ?: 0).coerceAtLeast(dockedWidthPx())
        return params.x + width / 2 < screenWidth / 2
    }

    /** Fully visible docked position (right after the user dragged the bubble). */
    private fun dockXFor(params: WindowManager.LayoutParams): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        val margin = dpToPx(4f)
        return if (isDockLeft(params)) margin else screenWidth - dockedWidthPx() - margin
    }

    /** Hidden position: the bubble is pushed into the screen edge, only a thin tab stays visible. */
    private fun peekXFor(dockLeft: Boolean): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        val peek = dpToPx(16f)
        return if (dockLeft) -(dockedWidthPx() - peek) else screenWidth - peek
    }

    private fun collapseToDockedIcon() {
        val params = rootParams ?: return
        if (overlayView == null) return

        try {
            // Decide the side while the pill is still expanded
            val dockLeft = isDockLeft(params)

            isExpanded = false
            isDocked = true

            pauseBtn?.visibility = View.GONE
            langBtn?.visibility = View.GONE
            appBtn?.visibility = View.GONE

            capsuleLayout?.animate()?.alpha(0.7f)?.setDuration(220L)?.start()
            animateOverlayX(peekXFor(dockLeft))
        } catch (e: Exception) {
            android.util.Log.e("FloatingOverlay", "Error auto-docking", e)
        }
    }

    private fun snapToNearestEdge() {
        val params = rootParams ?: return
        // After a drag the bubble rests visible at the edge; the inactivity timer then tucks it away again
        animateOverlayX(dockXFor(params), 160L)
    }

    private fun isPointInsideView(view: View?, rawX: Float, rawY: Float): Boolean {
        if (view == null || view.visibility != View.VISIBLE) return false
        val loc = IntArray(2)
        view.getLocationOnScreen(loc)
        val left = loc[0]
        val top = loc[1]
        val right = left + view.width
        val bottom = top + view.height
        return rawX >= left && rawX <= right && rawY >= top && rawY <= bottom
    }

    private fun updatePauseBtnUI(btnToUpdate: ImageView? = null) {
        val target = btnToUpdate ?: pauseBtn ?: return
        if (isPaused) {
            target.setImageResource(R.drawable.ic_overlay_play)
            target.background = circleBg(colLive)
            target.contentDescription = "Resume"
        } else {
            target.setImageResource(R.drawable.ic_overlay_pause)
            target.background = circleBg(colButton)
            target.contentDescription = "Pause"
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
        statusDot?.background = statusRing()
        updatePauseBtnUI()
        langBtn?.text = "$targetLangFlag  $targetLang"
    }

    /**
     * Shows a full-fidelity native modal dialog overlay containing all 71 languages
     * with live search and instant selection.
     */
    @SuppressLint("ClickableViewAccessibility")
    private fun showLanguagePickerDialog() {
        if (langDialogView != null) {
            dismissLanguagePickerDialog()
            return
        }

        // Pause auto-dock timer while user interacts with language picker
        inactivityHandler.removeCallbacks(autoDockRunnable)

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // Needs focus so the soft keyboard works for search input
        val dialogParams = WindowManager.LayoutParams(
            dpToPx(320f),
            dpToPx(440f),
            layoutType,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            dimAmount = 0.55f
        }

        // Dialog Root Card Container
        val dialogCard = object : LinearLayout(this) {
            override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
                if (event.keyCode == android.view.KeyEvent.KEYCODE_BACK &&
                    event.action == android.view.KeyEvent.ACTION_UP) {
                    dismissLanguagePickerDialog(restartInactivityTimer = true)
                    return true
                }
                return super.dispatchKeyEvent(event)
            }
        }.apply {
            orientation = LinearLayout.VERTICAL
            isFocusableInTouchMode = true
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(20f).toFloat()
                setColor(Color.parseColor("#0F172A")) // Slate-900
                setStroke(dpToPx(1.5f), Color.parseColor("#334155")) // Slate-700
            }
            setPadding(dpToPx(16f), dpToPx(14f), dpToPx(16f), dpToPx(16f))
            elevation = dpToPx(16f).toFloat()
        }

        // Header Row: Title + Count + Close (✕)
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(10f)
            }
        }

        val titleContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleText = TextView(this).apply {
            text = "Select Language"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
        }
        titleContainer.addView(titleText)

        val subtitleText = TextView(this).apply {
            text = "${OVERLAY_LANGUAGES.size} Languages · Real-time Neural Voice"
            setTextColor(Color.parseColor("#94A3B8")) // Slate-400
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
        }
        titleContainer.addView(subtitleText)
        headerRow.addView(titleContainer)

        val closeBtn = TextView(this).apply {
            text = "✕"
            setTextColor(Color.parseColor("#94A3B8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            val size = dpToPx(30f)
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#1E293B"))
            }
            setOnClickListener {
                dismissLanguagePickerDialog(restartInactivityTimer = true)
            }
        }
        headerRow.addView(closeBtn)
        dialogCard.addView(headerRow)

        // Search Input Field
        val searchBox = EditText(this).apply {
            hint = "Search ${OVERLAY_LANGUAGES.size} languages..."
            setHintTextColor(Color.parseColor("#64748B")) // Slate-500
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            isSingleLine = true
            setPadding(dpToPx(12f), dpToPx(9f), dpToPx(12f), dpToPx(9f))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dpToPx(12f).toFloat()
                setColor(Color.parseColor("#1E293B")) // Slate-800
                setStroke(dpToPx(1f), Color.parseColor("#334155"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(40f)
            ).apply {
                bottomMargin = dpToPx(10f)
            }
        }
        dialogCard.addView(searchBox)

        // Scrollable List Container
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
            isFillViewport = true
        }

        val listContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        scrollView.addView(listContainer)
        dialogCard.addView(scrollView)

        // Populate Language Items
        fun renderLanguages(filterQuery: String) {
            listContainer.removeAllViews()
            val query = filterQuery.trim().lowercase()

            val filtered = if (query.isEmpty()) {
                OVERLAY_LANGUAGES
            } else {
                OVERLAY_LANGUAGES.filter {
                    it.name.lowercase().contains(query) ||
                    it.abbr.lowercase().contains(query) ||
                    it.code.lowercase().contains(query)
                }
            }

            for (lang in filtered) {
                val isSelected = lang.abbr.equals(targetLang, ignoreCase = true) ||
                                 lang.code.equals(targetLang, ignoreCase = true)

                val itemRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        dpToPx(42f)
                    ).apply {
                        bottomMargin = dpToPx(4f)
                    }
                    setPadding(dpToPx(10f), 0, dpToPx(10f), 0)
                    background = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = dpToPx(10f).toFloat()
                        if (isSelected) {
                            setColor(Color.parseColor("#1E3A5F")) // Slate/Blue selected highlight
                            setStroke(dpToPx(1f), Color.parseColor("#38BDF8"))
                        } else {
                            setColor(Color.parseColor("#141D2E")) // Slate-900 item bg
                        }
                    }

                    // Flag
                    val flagView = TextView(this@FloatingOverlayService).apply {
                        text = lang.flag
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                        layoutParams = LinearLayout.LayoutParams(dpToPx(30f), LinearLayout.LayoutParams.WRAP_CONTENT)
                    }
                    addView(flagView)

                    // Language Name
                    val nameView = TextView(this@FloatingOverlayService).apply {
                        text = lang.name
                        setTextColor(if (isSelected) Color.WHITE else Color.parseColor("#E2E8F0"))
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                        setTypeface(typeface, if (isSelected) Typeface.BOLD else Typeface.NORMAL)
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    }
                    addView(nameView)

                    // Abbreviation Badge
                    val codeBadge = TextView(this@FloatingOverlayService).apply {
                        text = lang.abbr
                        setTextColor(if (isSelected) Color.parseColor("#38BDF8") else Color.parseColor("#94A3B8"))
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                        setTypeface(typeface, Typeface.BOLD)
                        setPadding(dpToPx(6f), dpToPx(2f), dpToPx(6f), dpToPx(2f))
                        background = GradientDrawable().apply {
                            shape = GradientDrawable.RECTANGLE
                            cornerRadius = dpToPx(6f).toFloat()
                            setColor(Color.parseColor("#1E293B"))
                        }
                    }
                    addView(codeBadge)

                    if (isSelected) {
                        val checkView = TextView(this@FloatingOverlayService).apply {
                            text = " ✓"
                            setTextColor(Color.parseColor("#10B981")) // Emerald
                            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                            setTypeface(typeface, Typeface.BOLD)
                        }
                        addView(checkView)
                    }

                    setOnClickListener {
                        targetLang = lang.abbr
                        targetLangFlag = lang.flag
                        targetLangName = lang.name
                        updateOverlayUI()
                        dismissLanguagePickerDialog(restartInactivityTimer = true)
                        MainActivity.triggerLanguageSelected(lang.code)
                    }
                }
                listContainer.addView(itemRow)
            }
        }

        renderLanguages("")

        // Search text watcher for real-time list filtering
        searchBox.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                renderLanguages(s?.toString() ?: "")
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        // Dismiss if user taps outside dialog card
        dialogCard.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                dismissLanguagePickerDialog(restartInactivityTimer = true)
                true
            } else {
                false
            }
        }

        dialogCard.requestFocus()
        langDialogView = dialogCard
        try {
            windowManager?.addView(langDialogView, dialogParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun dismissLanguagePickerDialog(restartInactivityTimer: Boolean = false) {
        if (langDialogView != null) {
            try {
                windowManager?.removeView(langDialogView)
            } catch (_: Exception) {}
            langDialogView = null
            if (restartInactivityTimer && isTranslating && overlayView != null) {
                resetInactivityTimer()
            }
        }
    }

    private fun removeOverlayView() {
        dockAnimator?.cancel()
        dockAnimator = null
        inactivityHandler.removeCallbacks(autoDockRunnable)
        dismissLanguagePickerDialog()
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {}
            overlayView = null
            isServiceRunning = false
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        android.util.Log.i("FloatingOverlay", "App swiped away from Recents. Removing overlay and stopping service.")
        inactivityHandler.removeCallbacks(autoDockRunnable)
        releaseWakeLock()
        dismissLanguagePickerDialog()
        removeOverlayView()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        hasMediaProjectionPermission = false
        inactivityHandler.removeCallbacks(autoDockRunnable)
        releaseWakeLock()
        dismissLanguagePickerDialog()
        removeOverlayView()
        isForegroundActive = false
        onForegroundReadyListener = null
        super.onDestroy()
    }
}

