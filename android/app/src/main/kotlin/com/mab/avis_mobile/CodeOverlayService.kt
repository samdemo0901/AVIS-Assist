package com.mab.avis_mobile

import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.view.animation.DecelerateInterpolator
import android.view.animation.AccelerateInterpolator
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.*
import java.util.regex.Pattern

/**
 * AVIS Futuristic Code Overlay Service
 * Displays a premium floating code popup with syntax highlighting,
 * HTML live preview, copy button, slide animation, and auto-dismiss with touch-pause.
 */
class CodeOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var dismissHandler: Handler? = null
    private var dismissRunnable: Runnable? = null
    private var progressHandler: Handler? = null
    private var progressRunnable: Runnable? = null
    
    private var remainingMs: Long = AUTO_DISMISS_MS
    private var isPaused: Boolean = false

    companion object {
        const val AUTO_DISMISS_MS: Long = 8000
        const val PROGRESS_TICK_MS: Long = 50
        const val ANIM_DURATION: Long = 400

        // Neon color palette
        const val COLOR_BG_PANEL = 0xF0080C18.toInt()
        const val COLOR_BG_HEADER = 0xF00E1426.toInt()
        const val COLOR_BG_CODE = 0xFA060812.toInt()
        const val COLOR_BORDER = 0x7800E5FF.toInt()
        const val COLOR_NEON_CYAN = 0xFF00E5FF.toInt()
        const val COLOR_NEON_MAGENTA = 0xFFD946EF.toInt()
        const val COLOR_NEON_GREEN = 0xFF00FF9D.toInt()
        const val COLOR_TEXT_DEFAULT = 0xFFC8D6E5.toInt()
        const val COLOR_TEXT_COMMENT = 0xFF636E72.toInt()
        const val COLOR_TEXT_STRING = 0xFF00FF9D.toInt()
        const val COLOR_TEXT_KEYWORD = 0xFFD946EF.toInt()
        const val COLOR_TEXT_BUILTIN = 0xFF00E5FF.toInt()
        const val COLOR_TEXT_NUMBER = 0xFFFF9100.toInt()
        const val COLOR_TEXT_FUNCTION = 0xFF448AFF.toInt()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val code = intent?.getStringExtra("code") ?: ""
        val language = intent?.getStringExtra("language") ?: "text"
        val title = intent?.getStringExtra("title") ?: "${language.uppercase()} Code"

        if (code.isNotEmpty()) {
            showOverlay(code, language, title)
        }

        return START_NOT_STICKY
    }

    private fun showOverlay(code: String, language: String, title: String) {
        // Remove any existing overlay first
        removeOverlay()

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager?.defaultDisplay?.getMetrics(metrics)
        val screenWidth = metrics.widthPixels
        val screenHeight = metrics.heightPixels
        val overlayWidth = (screenWidth * 0.88).toInt()

        val params = WindowManager.LayoutParams(
            overlayWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.END or Gravity.TOP
            x = dpToPx(10f).toInt()
            y = dpToPx(55f).toInt()
        }

        overlayView = buildOverlayView(code, language, title, overlayWidth, screenHeight)
        
        try {
            windowManager?.addView(overlayView, params)
            slideIn(overlayWidth)
            startAutoDismiss()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun buildOverlayView(code: String, language: String, title: String, width: Int, screenHeight: Int): View {
        val ctx = this
        val isHtml = language.equals("html", ignoreCase = true) || 
                     code.contains("<html>", ignoreCase = true) || 
                     code.contains("<!DOCTYPE html>", ignoreCase = true)

        // ── Root Container ──
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                setColor(COLOR_BG_PANEL)
                cornerRadius = dpToPx(14f)
                setStroke(dpToPx(1f).toInt(), COLOR_BORDER)
            }
            background = bg
            elevation = dpToPx(8f)
            clipChildren = true
            clipToPadding = true
        }

        // ── Header Bar ──
        val header = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val bg = GradientDrawable().apply {
                setColor(COLOR_BG_HEADER)
                cornerRadii = floatArrayOf(
                    dpToPx(14f), dpToPx(14f),
                    dpToPx(14f), dpToPx(14f),
                    0f, 0f, 0f, 0f
                )
            }
            background = bg
            setPadding(dpToPx(12f).toInt(), dpToPx(8f).toInt(), dpToPx(10f).toInt(), dpToPx(8f).toInt())
        }

        // Language badge
        val langBadge = TextView(ctx).apply {
            text = "⟨ ${language.uppercase()} ⟩"
            setTextColor(COLOR_NEON_CYAN)
            textSize = 11f
            typeface = Typeface.MONOSPACE
            setTypeface(typeface, Typeface.BOLD)
        }
        header.addView(langBadge)

        // Title
        val titleView = TextView(ctx).apply {
            text = title
            setTextColor(COLOR_TEXT_DEFAULT)
            textSize = 11f
            gravity = Gravity.CENTER
            setPadding(dpToPx(6f).toInt(), 0, dpToPx(6f).toInt(), 0)
        }
        header.addView(titleView, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        var webView: WebView? = null
        var scroll: HorizontalScrollView? = null
        var isShowingPreview = isHtml

        if (isHtml) {
            val toggleBtn = TextView(ctx).apply {
                text = "🌐 Preview"
                setTextColor(COLOR_NEON_GREEN)
                textSize = 11f
                typeface = Typeface.DEFAULT_BOLD
                val bg = GradientDrawable().apply {
                    setColor(0x1E00FF9D)
                    cornerRadius = dpToPx(6f)
                    setStroke(dpToPx(1f).toInt(), 0x5000FF9D)
                }
                background = bg
                setPadding(dpToPx(8f).toInt(), dpToPx(4f).toInt(), dpToPx(8f).toInt(), dpToPx(4f).toInt())
            }
            header.addView(toggleBtn)

            toggleBtn.setOnClickListener {
                isShowingPreview = !isShowingPreview
                if (isShowingPreview) {
                    toggleBtn.text = "💻 Code"
                    toggleBtn.setTextColor(COLOR_NEON_CYAN)
                    scroll?.visibility = View.GONE
                    webView?.visibility = View.VISIBLE
                } else {
                    toggleBtn.text = "🌐 Preview"
                    toggleBtn.setTextColor(COLOR_NEON_GREEN)
                    webView?.visibility = View.GONE
                    scroll?.visibility = View.VISIBLE
                }
            }
        }

        // Copy button
        val copyBtn = TextView(ctx).apply {
            text = "📋 Copy"
            setTextColor(COLOR_NEON_CYAN)
            textSize = 11f
            typeface = Typeface.DEFAULT_BOLD
            val bg = GradientDrawable().apply {
                setColor(0x1E00E5FF)
                cornerRadius = dpToPx(6f)
                setStroke(dpToPx(1f).toInt(), 0x5000E5FF)
            }
            background = bg
            setPadding(dpToPx(10f).toInt(), dpToPx(4f).toInt(), dpToPx(10f).toInt(), dpToPx(4f).toInt())
            setOnClickListener {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("AVIS Code", code))
                text = "✅ Copied!"
                setTextColor(COLOR_NEON_GREEN)
                Handler(Looper.getMainLooper()).postDelayed({
                    text = "📋 Copy"
                    setTextColor(COLOR_NEON_CYAN)
                }, 1500)
            }
        }
        header.addView(copyBtn)

        // Close button
        val closeBtn = TextView(ctx).apply {
            text = "✕"
            setTextColor(COLOR_TEXT_COMMENT)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dpToPx(8f).toInt(), 0, dpToPx(4f).toInt(), 0)
            setOnClickListener { slideOut() }
        }
        header.addView(closeBtn)

        root.addView(header, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // ── Code View (Scroll) ──
        scroll = HorizontalScrollView(ctx).apply {
            isHorizontalScrollBarEnabled = false
            visibility = if (isHtml) View.GONE else View.VISIBLE
        }
        val vScroll = ScrollView(ctx).apply {
            isVerticalScrollBarEnabled = true
        }
        
        val codeView = TextView(ctx).apply {
            val highlighted = highlightSyntax(code, language)
            text = highlighted
            typeface = Typeface.MONOSPACE
            textSize = 12f
            setTextColor(COLOR_TEXT_DEFAULT)
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dpToPx(14f).toInt(), dpToPx(12f).toInt(), dpToPx(14f).toInt(), dpToPx(12f).toInt())
            setTextIsSelectable(false)
            setLineSpacing(dpToPx(3f), 1f)
        }
        
        vScroll.addView(codeView)
        scroll.addView(vScroll, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        // ── HTML WebView Container ──
        if (isHtml) {
            webView = WebView(ctx).apply {
                webViewClient = WebViewClient()
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.useWideViewPort = true
                settings.loadWithOverviewMode = true
                setBackgroundColor(0xFFFFFFFF.toInt())
                visibility = View.VISIBLE

                val formattedHtml = if (!code.contains("viewport", ignoreCase = true)) {
                    "<!DOCTYPE html><html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\"><style>html,body{margin:0;padding:4px;width:100%;box-sizing:border-box;}</style></head><body>$code</body></html>"
                } else {
                    code
                }
                loadDataWithBaseURL(null, formattedHtml, "text/html", "UTF-8", null)
            }
        }

        // Dynamic & Responsive Height for Code / Preview Area
        val lineCount = code.count { it == '\n' } + 1
        val maxCodeHeight = (screenHeight * 0.62).toInt()
        val minCodeHeight = dpToPx(45f).toInt()
        val estHeight = (lineCount * dpToPx(18f)).toInt() + dpToPx(24f).toInt()
        val codeHeight = minOf(maxOf(estHeight, minCodeHeight), maxCodeHeight)

        root.addView(scroll, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, codeHeight
        ))

        if (isHtml && webView != null) {
            root.addView(webView, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, codeHeight
            ))
        }

        // ── Progress Bar ──
        val progressContainer = FrameLayout(ctx).apply {
            val bg = GradientDrawable().apply {
                setColor(0xFF0A0E1C.toInt())
            }
            background = bg
        }
        
        val progressBar = View(ctx).apply {
            tag = "progressBar"
            val grad = GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(COLOR_NEON_CYAN, COLOR_NEON_MAGENTA, COLOR_NEON_CYAN)
            )
            grad.cornerRadius = dpToPx(1.5f)
            background = grad
        }
        progressContainer.addView(progressBar, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, dpToPx(3f).toInt()
        ))
        root.addView(progressContainer, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dpToPx(3f).toInt()
        ))

        // ── Footer ──
        val footer = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val bg = GradientDrawable().apply {
                setColor(COLOR_BG_HEADER)
                cornerRadii = floatArrayOf(
                    0f, 0f, 0f, 0f,
                    dpToPx(14f), dpToPx(14f),
                    dpToPx(14f), dpToPx(14f)
                )
            }
            background = bg
            setPadding(dpToPx(12f).toInt(), dpToPx(4f).toInt(), dpToPx(12f).toInt(), dpToPx(6f).toInt())
        }

        val avisTag = TextView(ctx).apply {
            text = "⚡ AVIS Code Overlay"
            setTextColor(0x6600E5FF)
            textSize = 9f
        }
        footer.addView(avisTag, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        val timerLabel = TextView(ctx).apply {
            tag = "timerLabel"
            text = "8.0s"
            setTextColor(0x5000E5FF)
            textSize = 9f
            typeface = Typeface.MONOSPACE
            gravity = Gravity.END
        }
        footer.addView(timerLabel)

        root.addView(footer, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // ── Tap-to-Pause & Touch Events for Timer Control ──
        var isPausedByTap = false

        root.setOnClickListener {
            isPausedByTap = !isPausedByTap
            isPaused = isPausedByTap
            val timerLabel = overlayView?.findViewWithTag<TextView>("timerLabel")
            if (isPausedByTap) {
                timerLabel?.apply {
                    text = "⏸ PAUSED"
                    setTextColor(COLOR_NEON_MAGENTA)
                }
            } else {
                timerLabel?.apply {
                    text = String.format("%.1fs", remainingMs / 1000f)
                    setTextColor(0x5000E5FF)
                }
            }
        }

        root.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    if (!isPausedByTap) {
                        isPaused = true
                        overlayView?.findViewWithTag<TextView>("timerLabel")?.apply {
                            text = "⏸ PAUSED"
                            setTextColor(COLOR_NEON_MAGENTA)
                        }
                    }
                }
                MotionEvent.ACTION_UP -> {
                    view.performClick()
                    if (!isPausedByTap) {
                        isPaused = false
                        overlayView?.findViewWithTag<TextView>("timerLabel")?.apply {
                            setTextColor(0x5000E5FF)
                        }
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    if (!isPausedByTap) {
                        isPaused = false
                        overlayView?.findViewWithTag<TextView>("timerLabel")?.apply {
                            setTextColor(0x5000E5FF)
                        }
                    }
                }
            }
            true
        }

        return root
    }

    // ─── Syntax Highlighting ─────────────────────────────────────────────

    private fun highlightSyntax(code: String, language: String): SpannableStringBuilder {
        val ssb = SpannableStringBuilder(code)
        val lang = language.lowercase()

        // Keywords
        val keywords = when (lang) {
            "python" -> listOf(
                "False", "None", "True", "and", "as", "assert", "async", "await",
                "break", "class", "continue", "def", "del", "elif", "else",
                "except", "finally", "for", "from", "global", "if", "import",
                "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise",
                "return", "try", "while", "with", "yield"
            )
            "javascript", "js" -> listOf(
                "async", "await", "break", "case", "catch", "class", "const",
                "continue", "default", "delete", "do", "else", "export", "extends",
                "false", "finally", "for", "function", "if", "import", "in",
                "instanceof", "let", "new", "null", "of", "return", "static",
                "super", "switch", "this", "throw", "true", "try", "typeof",
                "undefined", "var", "void", "while", "with", "yield"
            )
            "dart" -> listOf(
                "abstract", "as", "assert", "async", "await", "break", "case",
                "catch", "class", "const", "continue", "default", "do", "dynamic",
                "else", "enum", "extends", "factory", "false", "final", "finally",
                "for", "Function", "get", "if", "implements", "import", "in",
                "is", "late", "new", "null", "return", "set", "static", "super",
                "switch", "this", "throw", "true", "try", "var", "void", "while", "with", "yield"
            )
            else -> emptyList()
        }

        // Apply keyword highlighting
        for (kw in keywords) {
            val pattern = Pattern.compile("\\b${Pattern.quote(kw)}\\b")
            val matcher = pattern.matcher(code)
            while (matcher.find()) {
                ssb.setSpan(
                    ForegroundColorSpan(COLOR_TEXT_KEYWORD),
                    matcher.start(), matcher.end(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                ssb.setSpan(
                    StyleSpan(Typeface.BOLD),
                    matcher.start(), matcher.end(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
        }

        // Strings (double and single quoted)
        val stringPattern = Pattern.compile("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"|'[^'\\\\]*(\\\\.[^'\\\\]*)*'")
        val strMatcher = stringPattern.matcher(code)
        while (strMatcher.find()) {
            ssb.setSpan(
                ForegroundColorSpan(COLOR_TEXT_STRING),
                strMatcher.start(), strMatcher.end(),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        // Numbers
        val numPattern = Pattern.compile("\\b\\d+\\.?\\d*([eE][+-]?\\d+)?\\b")
        val numMatcher = numPattern.matcher(code)
        while (numMatcher.find()) {
            ssb.setSpan(
                ForegroundColorSpan(COLOR_TEXT_NUMBER),
                numMatcher.start(), numMatcher.end(),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        // Comments
        val commentPattern = when (lang) {
            "python" -> Pattern.compile("#.*$", Pattern.MULTILINE)
            "javascript", "js", "dart", "json" -> Pattern.compile("//.*$", Pattern.MULTILINE)
            else -> null
        }
        commentPattern?.let {
            val cMatcher = it.matcher(code)
            while (cMatcher.find()) {
                ssb.setSpan(
                    ForegroundColorSpan(COLOR_TEXT_COMMENT),
                    cMatcher.start(), cMatcher.end(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
                ssb.setSpan(
                    StyleSpan(Typeface.ITALIC),
                    cMatcher.start(), cMatcher.end(),
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }
        }

        // Function calls
        val funcPattern = Pattern.compile("\\b([a-zA-Z_]\\w*)\\s*\\(")
        val funcMatcher = funcPattern.matcher(code)
        while (funcMatcher.find()) {
            ssb.setSpan(
                ForegroundColorSpan(COLOR_TEXT_FUNCTION),
                funcMatcher.start(1), funcMatcher.end(1),
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }

        return ssb
    }

    // ─── Animations ──────────────────────────────────────────────────────

    private fun slideIn(width: Int) {
        overlayView?.let { view ->
            view.translationX = width.toFloat()
            view.animate()
                .translationX(0f)
                .setDuration(ANIM_DURATION)
                .setInterpolator(DecelerateInterpolator(1.5f))
                .start()
        }
    }

    private fun slideOut() {
        overlayView?.let { view ->
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager?.defaultDisplay?.getMetrics(metrics)
            
            view.animate()
                .translationX(metrics.widthPixels.toFloat())
                .setDuration(350)
                .setInterpolator(AccelerateInterpolator(1.5f))
                .withEndAction {
                    removeOverlay()
                    stopSelf()
                }
                .start()
        }
    }

    // ─── Auto-Dismiss Timer ──────────────────────────────────────────────

    private fun startAutoDismiss() {
        remainingMs = AUTO_DISMISS_MS
        dismissHandler = Handler(Looper.getMainLooper())
        progressHandler = Handler(Looper.getMainLooper())

        progressRunnable = object : Runnable {
            override fun run() {
                if (!isPaused) {
                    remainingMs -= PROGRESS_TICK_MS

                    // Update progress bar width
                    val progress = remainingMs.toFloat() / AUTO_DISMISS_MS.toFloat()
                    overlayView?.findViewWithTag<View>("progressBar")?.let { bar ->
                        val parent = bar.parent as? ViewGroup
                        parent?.let {
                            val lp = bar.layoutParams as FrameLayout.LayoutParams
                            lp.width = (it.width * progress).toInt()
                            bar.layoutParams = lp
                        }
                    }

                    // Update timer label
                    overlayView?.findViewWithTag<TextView>("timerLabel")?.let { label ->
                        if (!isPaused) {
                            label.text = String.format("%.1fs", remainingMs / 1000f)
                        }
                    }

                    if (remainingMs <= 0) {
                        slideOut()
                        return
                    }
                }

                progressHandler?.postDelayed(this, PROGRESS_TICK_MS)
            }
        }
        progressHandler?.postDelayed(progressRunnable!!, PROGRESS_TICK_MS)
    }

    private fun removeOverlay() {
        progressHandler?.removeCallbacksAndMessages(null)
        dismissHandler?.removeCallbacksAndMessages(null)
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        overlayView = null
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    // ─── Utility ─────────────────────────────────────────────────────────

    private fun dpToPx(dp: Float): Float {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp,
            resources.displayMetrics
        )
    }
}
