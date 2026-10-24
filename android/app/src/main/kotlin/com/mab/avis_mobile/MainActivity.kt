package com.mab.avis_mobile

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.BatteryManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.hardware.display.VirtualDisplay
import android.hardware.display.DisplayManager
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.media.ImageReader
import java.io.ByteArrayOutputStream
import android.os.HandlerThread
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import android.provider.Telephony
import android.telephony.TelephonyManager
import android.view.KeyEvent
import android.app.ActivityManager
import java.util.Calendar
import java.util.TimeZone
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        var instance: MainActivity? = null
    }

    private val METHOD_CHANNEL = "com.example.avis_mobile/audio"
    private val EVENT_CHANNEL = "com.example.avis_mobile/audio_stream"
    private val AUTOMATION_CHANNEL = "com.example.avis_mobile/automation"
    private val PERMISSIONS_CHANNEL = "com.example.avis_mobile/permissions"
    private val SCREEN_STREAM_CHANNEL = "com.example.avis_mobile/screen_stream"

    private var screenEventSink: EventChannel.EventSink? = null
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private val isScreenCasting = AtomicBoolean(false)
    private var lastFrameTime: Long = 0
    private val SCREEN_CAPTURE_REQUEST_CODE = 2001
    private var screenCaptureWorkerThread: HandlerThread? = null
    private var screenCaptureHandler: Handler? = null

    private var audioRecord: AudioRecord? = null
    private val isRecording = AtomicBoolean(false)
    private var recordingThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null

    private var echoCanceler: AcousticEchoCanceler? = null
    private var noiseSuppressor: NoiseSuppressor? = null
    private var gainControl: AutomaticGainControl? = null

    private var audioTrack: AudioTrack? = null
    private val isPlaying = AtomicBoolean(false)
    private var playbackThread: Thread? = null
    private val audioQueue = ConcurrentLinkedQueue<ByteArray>()

    private val sampleRateRecord = 16000
    private val sampleRatePlay = 24000

    private val mainHandler = Handler(Looper.getMainLooper())
    private var audioMethodChannel: MethodChannel? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var phoneStateReceiver: BroadcastReceiver? = null
    private var isMuted = false

    private var isTorchOn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        volumeControlStream = AudioManager.STREAM_MUSIC
        checkAndRequestPermissions()
        registerPhoneStateReceiver()
        handleAssistIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAssistIntent(intent)
    }

    private fun handleAssistIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_ASSIST || intent?.action == Intent.ACTION_VOICE_COMMAND) {
            mainHandler.postDelayed({
                audioMethodChannel?.invokeMethod("onAssistLaunch", null)
            }, 300)
        }
    }

    private fun checkAndRequestPermissions(): Boolean {
        val neededPerms = mutableListOf<String>()
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            neededPerms.add(android.Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                neededPerms.add(android.Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
        if (neededPerms.isNotEmpty()) {
            requestPermissions(neededPerms.toTypedArray(), 1001)
            return false
        }
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            if (!isRecording.get()) {
                startRecording()
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for microphone PCM stream
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

        // EventChannel for real-time JPEG screen projection stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    screenEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    screenEventSink = null
                    stopScreenCast()
                }
            }
        )

        // MethodChannel for audio control & permissions
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        audioMethodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    val granted = checkAndRequestPermissions()
                    result.success(granted)
                }
                "startRecording" -> {
                    startRecording()
                    result.success(true)
                }
                "stopRecording" -> {
                    stopRecording()
                    result.success(true)
                }
                "playPcmChunk" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes != null) {
                        playPcmChunk(bytes)
                    }
                    result.success(true)
                }
                "testSpeakerChime" -> {
                    testSpeakerChime()
                    result.success(true)
                }
                "playSciFiStartChime" -> {
                    playSciFiStartChime()
                    result.success(true)
                }
                "playSciFiEndChime" -> {
                    playSciFiEndChime()
                    result.success(true)
                }
                "stopPlayback" -> {
                    stopPlayback()
                    result.success(true)
                }
                "setAudioRoute" -> {
                    val map = call.arguments as? Map<*, *>
                    val route = map?.get("route") as? String ?: "AUTO"
                    setAudioRoute(route)
                    result.success(true)
                }
                "setMuteState" -> {
                    val muted = call.argument<Boolean>("isMuted") ?: false
                    isMuted = muted
                    VoiceForegroundService.updateState(this, isMuted)
                    result.success(true)
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel for APCS (Advanced Phone Control System) Automation
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTOMATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "controlFlashlight" -> {
                    val action = call.argument<String>("action") ?: "TOGGLE"
                    val res = setFlashlight(action)
                    result.success(res)
                }
                "controlBluetooth" -> {
                    val action = call.argument<String>("action") ?: "TOGGLE"
                    val res = controlBluetooth(action)
                    result.success(res)
                }
                "controlBrightness" -> {
                    val level = call.argument<Int>("level") ?: 128
                    val res = controlBrightness(level)
                    result.success(res)
                }
                "controlWifi" -> {
                    val action = call.argument<String>("action") ?: "STATUS"
                    if (action.uppercase() == "STATUS") {
                        result.success(getWifiStatus())
                    } else {
                        result.success(openWifiSettings())
                    }
                }
                "readSms" -> {
                    val limit = call.argument<Int>("limit") ?: 5
                    val query = call.argument<String>("query")
                    val res = querySms(limit, query)
                    result.success(res)
                }
                "readNotifications" -> {
                    val limit = call.argument<Int>("limit") ?: 10
                    val filter = call.argument<String>("filter")
                    val res = queryNotifications(limit, filter)
                    result.success(res)
                }
                "performScreenAction" -> {
                    val action = call.argument<String>("action") ?: "HOME"
                    val targetText = call.argument<String>("targetText")
                    val direction = call.argument<String>("direction")
                    val res = handleAccessibilityAction(action, targetText, direction)
                    result.success(res)
                }
                "launchApp" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    val res = launchAppByName(appName)
                    result.success(res)
                }
                "typeText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val targetField = call.argument<String>("targetField")
                    val pressEnter = call.argument<Boolean>("pressEnter") ?: false
                    val typographyCadence = call.argument<Boolean>("typographyCadence") ?: true
                    val res = handleTypeText(text, targetField, pressEnter, typographyCadence)
                    result.success(res)
                }
                "showCodePopup" -> {
                    val code = call.argument<String>("code") ?: ""
                    val language = call.argument<String>("language") ?: "text"
                    val title = call.argument<String>("title") ?: ""
                    
                    // Check overlay permission
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        // Request overlay permission
                        val overlayIntent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(overlayIntent)
                        result.success("Overlay permission required — settings opened for user to grant permission.")
                    } else {
                        val serviceIntent = Intent(this, CodeOverlayService::class.java).apply {
                            putExtra("code", code)
                            putExtra("language", language)
                            putExtra("title", title)
                        }
                        startService(serviceIntent)
                        val lines = code.count { it == '\n' } + 1
                        result.success("Code overlay displayed ($lines lines of $language code)")
                    }
                }
                "getAppStoragePaths" -> {
                    val internalDir = filesDir.absolutePath
                    val externalDir = getExternalFilesDir(null)?.absolutePath ?: internalDir
                    val sandboxDir = java.io.File(externalDir, "avis_sandbox").apply { mkdirs() }.absolutePath
                    val memoryDir = java.io.File(internalDir, "avis_memory").apply { mkdirs() }.absolutePath
                    result.success(mapOf(
                        "internalDir" to internalDir,
                        "externalDir" to externalDir,
                        "sandboxDir" to sandboxDir,
                        "memoryDir" to memoryDir
                    ))
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val title = call.argument<String>("title") ?: "Share File"
                    if (filePath.isNotEmpty()) {
                        val file = java.io.File(filePath)
                        if (file.exists()) {
                            try {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    val mime = when {
                                        filePath.endsWith(".html") || filePath.endsWith(".htm") -> "text/html"
                                        filePath.endsWith(".png") || filePath.endsWith(".jpg") || filePath.endsWith(".jpeg") -> "image/*"
                                        filePath.endsWith(".json") -> "application/json"
                                        filePath.endsWith(".py") || filePath.endsWith(".js") || filePath.endsWith(".txt") -> "text/plain"
                                        else -> "*/*"
                                    }
                                    type = mime
                                    val fileContent = file.readText(Charsets.UTF_8)
                                    putExtra(Intent.EXTRA_TEXT, fileContent)
                                    putExtra(Intent.EXTRA_SUBJECT, file.name)
                                }
                                startActivity(Intent.createChooser(intent, title))
                                result.success(mapOf("success" to true, "message" to "Native share presented"))
                            } catch (e: Exception) {
                                result.success(mapOf("success" to false, "error" to e.message))
                            }
                        } else {
                            result.success(mapOf("success" to false, "error" to "File does not exist"))
                        }
                    } else {
                        result.success(mapOf("success" to false, "error" to "File path empty"))
                    }
                }
                "createCalendarEvent" -> {
                    val title = call.argument<String>("title") ?: ""
                    val description = call.argument<String>("description") ?: ""
                    val startMillis = call.argument<Long>("startMillis")
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 30
                    val location = call.argument<String>("location") ?: ""
                    val res = createCalendarEvent(title, description, startMillis, durationMinutes, location)
                    result.success(res)
                }
                "queryCalendarEvents" -> {
                    val daysAhead = call.argument<Int>("daysAhead") ?: 7
                    val query = call.argument<String>("query")
                    val res = queryCalendarEvents(daysAhead, query)
                    result.success(res)
                }
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 7
                    val minutes = call.argument<Int>("minutes") ?: 0
                    val message = call.argument<String>("message") ?: "AVIS Alarm"
                    val res = setAlarm(hour, minutes, message)
                    result.success(res)
                }
                "setTimer" -> {
                    val seconds = call.argument<Int>("seconds") ?: 60
                    val message = call.argument<String>("message") ?: "AVIS Timer"
                    val res = setTimer(seconds, message)
                    result.success(res)
                }
                "queryContacts" -> {
                    val query = call.argument<String>("query") ?: ""
                    val limit = call.argument<Int>("limit") ?: 10
                    val res = queryContacts(query, limit)
                    result.success(res)
                }
                "addContact" -> {
                    val name = call.argument<String>("name") ?: ""
                    val phone = call.argument<String>("phone") ?: ""
                    val email = call.argument<String>("email") ?: ""
                    val res = addContact(name, phone, email)
                    result.success(res)
                }
                "controlMedia" -> {
                    val action = call.argument<String>("action") ?: "TOGGLE"
                    val volume = call.argument<Int>("volume")
                    val res = controlMedia(action, volume)
                    result.success(res)
                }
                "closeApp" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    val packageNameArg = call.argument<String>("packageName") ?: ""
                    val res = closeApp(appName, packageNameArg)
                    result.success(res)
                }
                "getDeviceTelemetry" -> {
                    val res = getRealDeviceTelemetry()
                    result.success(res)
                }
                "openPermissionSettings" -> {
                    val settingType = call.argument<String>("settingType") ?: "GENERAL"
                    val res = openPermissionSettings(settingType)
                    result.success(res)
                }
                "sendWhatsAppMessage" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val res = sendWhatsAppMessage(phone, message)
                    result.success(res)
                }
                "startScreenCast" -> {
                    val started = startScreenCastPermissionRequest()
                    result.success(started)
                }
                "stopScreenCast" -> {
                    stopScreenCast()
                    result.success(true)
                }
                "isScreenCasting" -> {
                    result.success(isScreenCasting.get())
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel for Permissions & System Settings Management
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAllPermissions" -> {
                    result.success(checkPermissionsState())
                }
                "requestRuntimePermission" -> {
                    val perm = call.argument<String>("permission") ?: ""
                    when (perm.lowercase()) {
                        "audio" -> requestPermissions(arrayOf(android.Manifest.permission.RECORD_AUDIO), 1001)
                        "camera" -> requestPermissions(arrayOf(android.Manifest.permission.CAMERA), 1002)
                        "sms" -> requestPermissions(arrayOf(android.Manifest.permission.READ_SMS), 1003)
                        "calendar" -> requestPermissions(arrayOf(android.Manifest.permission.READ_CALENDAR, android.Manifest.permission.WRITE_CALENDAR), 1004)
                        "contacts" -> requestPermissions(arrayOf(android.Manifest.permission.READ_CONTACTS, android.Manifest.permission.WRITE_CONTACTS), 1005)
                    }
                    result.success(true)
                }
                "openSettings" -> {
                    val target = call.argument<String>("target") ?: "app_settings"
                    openTargetSettings(target)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==========================================
    // AUDIO ENGINE IMPLEMENTATION
    // ==========================================

    private fun setAudioRoute(route: String) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Native AI Assistant Profile: Maintain MODE_NORMAL
            audioManager.mode = AudioManager.MODE_NORMAL

            when (route.uppercase()) {
                "SPEAKER" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            audioManager.clearCommunicationDevice()
                        } catch (e: Exception) {}
                    }
                    if (audioManager.isBluetoothScoOn) {
                        try {
                            audioManager.stopBluetoothSco()
                            audioManager.isBluetoothScoOn = false
                        } catch (e: Exception) {}
                    }
                    audioManager.isSpeakerphoneOn = true
                }
                "BLUETOOTH" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val commDevices = audioManager.availableCommunicationDevices
                            val targetComm = commDevices.firstOrNull {
                                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                                it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
                            }
                            if (targetComm != null) {
                                audioManager.setCommunicationDevice(targetComm)
                            }
                        } catch (e: Exception) {}
                    }
                    try {
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                    } catch (e: Exception) {}
                    audioManager.isSpeakerphoneOn = false
                }
                else -> {
                    audioManager.isSpeakerphoneOn = false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startRecording() {
        if (!checkAndRequestPermissions()) return
        if (isRecording.get()) return

        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Native AI Assistant Audio Profile: Always maintain MODE_NORMAL
            audioManager.mode = AudioManager.MODE_NORMAL

            // Detect connected Bluetooth audio headset / earbuds
            var connectedBtInput: AudioDeviceInfo? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val inputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                connectedBtInput = inputDevices.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && it.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
                }
            }

            if (connectedBtInput != null) {
                // Earbuds connected: Route mic input to Bluetooth Headset
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val commDevices = audioManager.availableCommunicationDevices
                        val targetComm = commDevices.firstOrNull {
                            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                            it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
                        }
                        if (targetComm != null) {
                            audioManager.setCommunicationDevice(targetComm)
                        }
                    } catch (e: Exception) {}
                }
                // Wake up Bluetooth SCO audio hardware for headset mic (keeping MODE_NORMAL)
                try {
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                } catch (e: Exception) {}
                audioManager.isSpeakerphoneOn = false
            } else {
                // No earbuds connected: Built-in phone mic & loud speaker
                try {
                    if (audioManager.isBluetoothScoOn) {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        audioManager.clearCommunicationDevice()
                    }
                } catch (e: Exception) {}
                audioManager.isSpeakerphoneOn = true
            }

            val minBufSize = AudioRecord.getMinBufferSize(
                sampleRateRecord,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = Math.max(minBufSize * 4, 16384)

            // True AI Assistant sources: VOICE_RECOGNITION first, fallback to MIC
            val sources = intArrayOf(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                MediaRecorder.AudioSource.MIC,
                MediaRecorder.AudioSource.DEFAULT
            )

            var initializedRecord: AudioRecord? = null
            for (source in sources) {
                try {
                    val candidate = AudioRecord(
                        source,
                        sampleRateRecord,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        bufferSize
                    )
                    if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                        initializedRecord = candidate
                        break
                    } else {
                        candidate.release()
                    }
                } catch (e: Exception) {
                    // Try next source
                }
            }

            if (initializedRecord == null || initializedRecord.state != AudioRecord.STATE_INITIALIZED) {
                return
            }

            // Bind AudioRecord explicitly to the Bluetooth earbuds mic if connected
            if (connectedBtInput != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    initializedRecord.setPreferredDevice(connectedBtInput)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            audioRecord = initializedRecord
            val audioSessionId = initializedRecord.audioSessionId

            // Hardware Audio Enhancements
            try {
                if (AcousticEchoCanceler.isAvailable()) {
                    echoCanceler = AcousticEchoCanceler.create(audioSessionId)
                    echoCanceler?.enabled = true
                }
                if (NoiseSuppressor.isAvailable()) {
                    noiseSuppressor = NoiseSuppressor.create(audioSessionId)
                    noiseSuppressor?.enabled = true
                }
                if (AutomaticGainControl.isAvailable()) {
                    gainControl = AutomaticGainControl.create(audioSessionId)
                    gainControl?.enabled = true
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            audioRecord?.startRecording()
            isRecording.set(true)
            startForegroundVoiceService()

            recordingThread = Thread {
                val chunkSize = 2048
                val buffer = ByteArray(chunkSize)
                while (isRecording.get()) {
                    val read = audioRecord?.read(buffer, 0, chunkSize) ?: -1
                    if (read > 0) {
                        val chunk = ByteArray(read)
                        System.arraycopy(buffer, 0, chunk, 0, read)
                        runOnUiThread {
                            eventSink?.success(chunk)
                        }
                    } else if (read < 0) {
                        Thread.sleep(20)
                    }
                }
            }
            recordingThread?.isDaemon = true
            recordingThread?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopRecording() {
        if (!isRecording.get()) return
        isRecording.set(false)
        stopForegroundVoiceService()
        try {
            recordingThread?.interrupt()
            recordingThread = null

            echoCanceler?.release()
            echoCanceler = null
            noiseSuppressor?.release()
            noiseSuppressor = null
            gainControl?.release()
            gainControl = null

            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null

            // Clean up Bluetooth SCO / communication device link on stop
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                if (audioManager.isBluetoothScoOn) {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audioManager.clearCommunicationDevice()
                }
            } catch (e: Exception) {}
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun initAudioTrack() {
        try {
            if (audioTrack != null) {
                try {
                    audioTrack?.stop()
                    audioTrack?.release()
                } catch (e: Exception) {}
            }

            val minBufSize = AudioTrack.getMinBufferSize(
                sampleRatePlay,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = Math.max(minBufSize * 4, 32768)

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            val audioFormat = AudioFormat.Builder()
                .setSampleRate(sampleRatePlay)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build()

            audioTrack = AudioTrack(
                audioAttributes,
                audioFormat,
                bufferSize,
                AudioTrack.MODE_STREAM,
                AudioManager.AUDIO_SESSION_ID_GENERATE
            )

            // Lock output device: Bluetooth A2DP / SCO if available, else Built-in Loudspeaker.
            // Strictly avoids fallback to TYPE_BUILTIN_EARPIECE receiver.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val outDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    val btOutput = outDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && (
                            it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                            it.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                        ))
                    }
                    val speakerOutput = outDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    }
                    val targetOutput = btOutput ?: speakerOutput
                    if (targetOutput != null) {
                        audioTrack?.setPreferredDevice(targetOutput)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }

            audioTrack?.play()
            isPlaying.set(true)

            playbackThread = Thread {
                while (isPlaying.get()) {
                    val chunk = audioQueue.poll()
                    if (chunk != null && chunk.isNotEmpty()) {
                        audioTrack?.write(chunk, 0, chunk.size)
                        val rms = computeNativePcmRms(chunk)
                        if (rms > 0.001) {
                            mainHandler.post {
                                audioMethodChannel?.invokeMethod("onSpeakerAudioLevel", mapOf("level" to rms))
                            }
                        }
                    } else {
                        try {
                            Thread.sleep(10)
                        } catch (ie: InterruptedException) {
                            break
                        }
                    }
                }
            }
            playbackThread?.isDaemon = true
            playbackThread?.start()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playPcmChunk(bytes: ByteArray) {
        if (audioTrack == null || audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
            initAudioTrack()
        }
        audioQueue.offer(bytes)
    }

    private fun testSpeakerChime() {
        val sampleRate = 24000
        val durationMs = 450
        val numSamples = sampleRate * durationMs / 1000
        val buffer = ByteArray(numSamples * 2)
        for (i in 0 until numSamples) {
            val freq = if (i < numSamples / 2) 587.33 else 880.0 // Sci-fi chime (D5 -> A5)
            val sample = (Math.sin(2.0 * Math.PI * freq * i / sampleRate) * 16000.0).toInt()
            buffer[i * 2] = (sample and 0xFF).toByte()
            buffer[i * 2 + 1] = ((sample shr 8) and 0xFF).toByte()
        }
        playPcmChunk(buffer)
    }

    private fun playSciFiStartChime() {
        val sampleRate = 24000
        val durationMs = 350
        val numSamples = sampleRate * durationMs / 1000
        val buffer = ByteArray(numSamples * 2)

        val t1Samples = sampleRate * 100 / 1000
        val t2Samples = sampleRate * 100 / 1000

        for (i in 0 until numSamples) {
            val (freq, noteProgress) = when {
                i < t1Samples -> Pair(523.25, i.toDouble() / t1Samples)
                i < t1Samples + t2Samples -> Pair(659.25, (i - t1Samples).toDouble() / t2Samples)
                else -> Pair(880.00, (i - t1Samples - t2Samples).toDouble() / (numSamples - t1Samples - t2Samples))
            }

            val envelope = when {
                noteProgress < 0.1 -> noteProgress / 0.1
                noteProgress > 0.8 -> (1.0 - noteProgress) / 0.2
                else -> 1.0
            }

            val sampleVal = (Math.sin(2.0 * Math.PI * freq * i / sampleRate) * 14000.0 * envelope).toInt()
            buffer[i * 2] = (sampleVal and 0xFF).toByte()
            buffer[i * 2 + 1] = ((sampleVal shr 8) and 0xFF).toByte()
        }
        playPcmChunk(buffer)
    }

    private fun playSciFiEndChime() {
        val sampleRate = 24000
        val durationMs = 280
        val numSamples = sampleRate * durationMs / 1000
        val buffer = ByteArray(numSamples * 2)

        val t1Samples = sampleRate * 80 / 1000
        val t2Samples = sampleRate * 80 / 1000

        for (i in 0 until numSamples) {
            val (freq, noteProgress) = when {
                i < t1Samples -> Pair(880.00, i.toDouble() / t1Samples)
                i < t1Samples + t2Samples -> Pair(659.25, (i - t1Samples).toDouble() / t2Samples)
                else -> Pair(440.00, (i - t1Samples - t2Samples).toDouble() / (numSamples - t1Samples - t2Samples))
            }

            val envelope = when {
                noteProgress < 0.08 -> noteProgress / 0.08
                noteProgress > 0.7 -> Math.pow((1.0 - noteProgress) / 0.3, 1.5)
                else -> 1.0
            }

            val sampleVal = (Math.sin(2.0 * Math.PI * freq * i / sampleRate) * 13000.0 * envelope).toInt()
            buffer[i * 2] = (sampleVal and 0xFF).toByte()
            buffer[i * 2 + 1] = ((sampleVal shr 8) and 0xFF).toByte()
        }
        playPcmChunk(buffer)
    }

    private fun stopPlayback() {
        audioQueue.clear()
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // ==========================================
    // APCS AUTOMATION METHODS
    // ==========================================

    private fun setFlashlight(action: String): Map<String, Any> {
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return mapOf("success" to false, "error" to "No CameraManager available")

        val targetState = when (action.uppercase()) {
            "ON" -> true
            "OFF" -> false
            "TOGGLE" -> !isTorchOn
            else -> true
        }

        return try {
            val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                val chars = cameraManager.getCameraCharacteristics(id)
                chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            } ?: cameraManager.cameraIdList.firstOrNull() ?: "0"

            cameraManager.setTorchMode(cameraId, targetState)
            isTorchOn = targetState
            mapOf("success" to true, "isTorchOn" to isTorchOn, "action" to action)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Failed to set flashlight"))
        }
    }

    private fun getWifiStatus(): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val isWifiEnabled = wm?.isWifiEnabled ?: false
        var isConnected = false
        var ssid = ""

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm?.activeNetwork
                val caps = cm?.getNetworkCapabilities(network)
                isConnected = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            } else {
                @Suppress("DEPRECATION")
                val info = cm?.activeNetworkInfo
                isConnected = info?.type == ConnectivityManager.TYPE_WIFI && info.isConnected
            }

            if (isConnected) {
                val info = wm?.connectionInfo
                ssid = info?.ssid?.replace("\"", "") ?: ""
                if (ssid == "<unknown ssid>") ssid = "Connected Wi-Fi"
            }
        } catch (e: Exception) {
            // Ignore
        }

        return mapOf(
            "success" to true,
            "isWifiEnabled" to isWifiEnabled,
            "isConnected" to isConnected,
            "ssid" to ssid
        )
    }

    private fun openWifiSettings(): Map<String, Any> {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                Intent(Settings.Panel.ACTION_WIFI)
            } else {
                Intent(Settings.ACTION_WIFI_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            mapOf("success" to true, "openedSettings" to true)
        } catch (e: Exception) {
            val fallback = Intent(Settings.ACTION_WIFI_SETTINGS)
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(fallback)
            mapOf("success" to true, "openedSettings" to true)
        }
    }

    private fun querySms(limit: Int, query: String?): Map<String, Any> {
        if (checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return mapOf(
                "success" to false,
                "error" to "PERMISSION_DENIED",
                "message" to "SMS permission not granted. Please ask Azhar to grant SMS permission."
            )
        }

        val messages = mutableListOf<Map<String, Any>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.READ
        )
        val selection = if (!query.isNullOrBlank()) {
            "${Telephony.Sms.BODY} LIKE ? OR ${Telephony.Sms.ADDRESS} LIKE ?"
        } else null
        val selectionArgs = if (!query.isNullOrBlank()) {
            arrayOf("%$query%", "%$query%")
        } else null
        val sortOrder = "${Telephony.Sms.DATE} DESC LIMIT $limit"

        try {
            contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val idxAddr = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                val idxBody = cursor.getColumnIndex(Telephony.Sms.BODY)
                val idxDate = cursor.getColumnIndex(Telephony.Sms.DATE)
                val idxRead = cursor.getColumnIndex(Telephony.Sms.READ)

                while (cursor.moveToNext()) {
                    val addr = if (idxAddr >= 0) cursor.getString(idxAddr) ?: "" else ""
                    val body = if (idxBody >= 0) cursor.getString(idxBody) ?: "" else ""
                    val date = if (idxDate >= 0) cursor.getLong(idxDate) else 0L
                    val read = if (idxRead >= 0) cursor.getInt(idxRead) == 1 else true

                    messages.add(mapOf(
                        "sender" to addr,
                        "body" to body,
                        "timestamp" to date,
                        "isRead" to read
                    ))
                }
            }
            return mapOf("success" to true, "messages" to messages, "count" to messages.size)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Failed to read SMS"))
        }
    }

    private fun queryNotifications(limit: Int, appFilter: String?): Map<String, Any> {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        val isEnabled = flat.contains(packageName) || AvisNotificationService.isConnected
        if (!isEnabled) {
            return mapOf(
                "success" to false,
                "error" to "LISTENER_DISABLED",
                "message" to "Notification access is not enabled in Android Settings."
            )
        }

        val list = AvisNotificationService.getRecentNotifications(limit, appFilter)
        return mapOf("success" to true, "notifications" to list, "count" to list.size)
    }

    private fun handleAccessibilityAction(action: String, targetText: String?, direction: String?): Map<String, Any> {
        if (!AvisAccessibilityService.isServiceRunning) {
            return mapOf(
                "success" to false,
                "error" to "ACCESSIBILITY_DISABLED",
                "message" to "AVIS Accessibility Service is not enabled in Accessibility Settings."
            )
        }

        return when (action.uppercase()) {
            "BACK", "HOME", "RECENTS", "NOTIFICATIONS", "QUICK_SETTINGS", "LOCK_SCREEN" -> {
                val ok = AvisAccessibilityService.performGlobal(action)
                mapOf("success" to ok, "action" to action)
            }
            "CLICK_TEXT" -> {
                if (targetText.isNullOrBlank()) {
                    mapOf("success" to false, "error" to "Missing targetText to click")
                } else {
                    val ok = AvisAccessibilityService.clickByText(targetText)
                    mapOf("success" to ok, "action" to "CLICK_TEXT", "target" to targetText)
                }
            }
            "SCROLL_DOWN" -> {
                val ok = AvisAccessibilityService.scroll("DOWN")
                mapOf("success" to ok, "action" to "SCROLL_DOWN")
            }
            "SCROLL_UP" -> {
                val ok = AvisAccessibilityService.scroll("UP")
                mapOf("success" to ok, "action" to "SCROLL_UP")
            }
            "SCREEN_CONTENT" -> {
                val texts = AvisAccessibilityService.getScreenTexts(20)
                mapOf("success" to true, "action" to "SCREEN_CONTENT", "elements" to texts)
            }
            else -> mapOf("success" to false, "error" to "Unknown action: $action")
        }
    }

    private fun launchAppByName(appName: String): Map<String, Any> {
        val cleanName = appName.trim().lowercase()
        if (cleanName.isEmpty()) {
            return mapOf("success" to false, "error" to "EMPTY_NAME", "message" to "App name cannot be empty.")
        }

        // 1. Comprehensive alias map for Samsung Galaxy & Android apps
        val knownPackages = mapOf(
            "youtube" to "com.google.android.youtube",
            "whatsapp" to "com.whatsapp",
            "chrome" to "com.android.chrome",
            "google chrome" to "com.android.chrome",
            "browser" to "com.android.chrome",
            "internet" to "com.sec.android.app.sbrowser",
            "samsung internet" to "com.sec.android.app.sbrowser",
            "instagram" to "com.instagram.android",
            "spotify" to "com.spotify.music",
            "settings" to "com.android.settings",
            "setting" to "com.android.settings",
            "gallery" to "com.sec.android.gallery3d",
            "samsung gallery" to "com.sec.android.gallery3d",
            "photos" to "com.google.android.apps.photos",
            "google photos" to "com.google.android.apps.photos",
            "maps" to "com.google.android.apps.maps",
            "google maps" to "com.google.android.apps.maps",
            "calculator" to "com.sec.android.app.popupcalculator",
            "calc" to "com.sec.android.app.popupcalculator",
            "google calculator" to "com.google.android.calculator",
            "clock" to "com.sec.android.app.clockpackage",
            "alarm" to "com.sec.android.app.clockpackage",
            "google clock" to "com.google.android.deskclock",
            "camera" to "com.sec.android.app.camera",
            "samsung camera" to "com.sec.android.app.camera",
            "google camera" to "com.google.android.GoogleCamera",
            "files" to "com.sec.android.app.myfiles",
            "my files" to "com.sec.android.app.myfiles",
            "file manager" to "com.sec.android.app.myfiles",
            "google files" to "com.google.android.apps.nbu.files",
            "notes" to "com.samsung.android.app.notes",
            "samsung notes" to "com.samsung.android.app.notes",
            "google keep" to "com.google.android.keep",
            "keep" to "com.google.android.keep",
            "phone" to "com.samsung.android.dialer",
            "dialer" to "com.samsung.android.dialer",
            "contacts" to "com.samsung.android.contacts",
            "messages" to "com.samsung.android.messaging",
            "message" to "com.samsung.android.messaging",
            "google messages" to "com.google.android.apps.messaging",
            "gmail" to "com.google.android.gm",
            "telegram" to "org.telegram.messenger",
            "play store" to "com.android.vending",
            "playstore" to "com.android.vending",
            "google play" to "com.android.vending",
            "netflix" to "com.netflix.mediaclient",
            "twitter" to "com.twitter.android",
            "x" to "com.twitter.android",
            "chatgpt" to "com.openai.chatgpt",
            "drive" to "com.google.android.apps.docs",
            "google drive" to "com.google.android.apps.docs"
        )

        // Try direct launch via known package
        val targetPkg = knownPackages[cleanName]
        if (targetPkg != null) {
            val intent = packageManager.getLaunchIntentForPackage(targetPkg)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return mapOf("success" to true, "appName" to appName, "package" to targetPkg)
            }
        }

        // 2. Dynamic query across all installed launcher applications
        try {
            val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val activities = packageManager.queryIntentActivities(launcherIntent, 0)

            // Exact match on label first
            for (resolveInfo in activities) {
                val label = resolveInfo.loadLabel(packageManager).toString().lowercase()
                if (label == cleanName) {
                    val launchIntent = packageManager.getLaunchIntentForPackage(resolveInfo.activityInfo.packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        return mapOf(
                            "success" to true,
                            "appName" to resolveInfo.loadLabel(packageManager).toString(),
                            "package" to resolveInfo.activityInfo.packageName
                        )
                    }
                }
            }

            // Substring / fuzzy match
            for (resolveInfo in activities) {
                val label = resolveInfo.loadLabel(packageManager).toString().lowercase()
                val pkgName = resolveInfo.activityInfo.packageName.lowercase()

                if (label.contains(cleanName) || cleanName.contains(label) || pkgName.contains(cleanName)) {
                    val launchIntent = packageManager.getLaunchIntentForPackage(resolveInfo.activityInfo.packageName)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        return mapOf(
                            "success" to true,
                            "appName" to resolveInfo.loadLabel(packageManager).toString(),
                            "package" to resolveInfo.activityInfo.packageName
                        )
                    }
                }
            }
        } catch (e: Exception) {
            // Fallthrough
        }

        // Special generic intent fallbacks
        if (cleanName.contains("camera") || cleanName.contains("kamera")) {
            try {
                val camIntent = Intent(android.provider.MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
                camIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(camIntent)
                return mapOf("success" to true, "appName" to "Camera", "package" to "camera_intent")
            } catch (e: Exception) {}
        }
        if (cleanName.contains("setting") || cleanName.contains("settings")) {
            try {
                val setIntent = Intent(Settings.ACTION_SETTINGS)
                setIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(setIntent)
                return mapOf("success" to true, "appName" to "Settings", "package" to "settings_intent")
            } catch (e: Exception) {}
        }

        return mapOf(
            "success" to false,
            "error" to "APP_NOT_FOUND",
            "message" to "Application '$appName' device me nahi mili."
        )
    }

    private fun handleTypeText(
        text: String,
        targetField: String?,
        pressEnter: Boolean,
        typographyCadence: Boolean
    ): Map<String, Any> {
        if (!AvisAccessibilityService.isServiceRunning) {
            return mapOf(
                "success" to false,
                "error" to "ACCESSIBILITY_DISABLED",
                "message" to "AVIS Accessibility Service is not enabled. Please enable it in Accessibility Settings."
            )
        }

        val ok = AvisAccessibilityService.typeTextWithTypography(
            text = text,
            targetField = targetField,
            pressEnter = pressEnter,
            typographyCadence = typographyCadence
        )

        return mapOf(
            "success" to ok,
            "text" to text,
            "targetField" to (targetField ?: ""),
            "pressEnter" to pressEnter,
            "typographyCadence" to typographyCadence
        )
    }

    private fun createCalendarEvent(
        title: String,
        description: String,
        startMillis: Long?,
        durationMinutes: Int,
        location: String
    ): Map<String, Any> {
        if (checkSelfPermission(android.Manifest.permission.WRITE_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            return mapOf("success" to false, "error" to "PERMISSION_DENIED", "message" to "Calendar write permission not granted.")
        }
        try {
            val start = startMillis ?: System.currentTimeMillis()
            val end = start + (durationMinutes * 60 * 1000L)
            val calId = 1L

            val values = ContentValues().apply {
                put(CalendarContract.Events.DTSTART, start)
                put(CalendarContract.Events.DTEND, end)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DESCRIPTION, description)
                put(CalendarContract.Events.CALENDAR_ID, calId)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                if (location.isNotEmpty()) {
                    put(CalendarContract.Events.EVENT_LOCATION, location)
                }
            }

            val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            return if (uri != null) {
                mapOf("success" to true, "eventUri" to uri.toString(), "title" to title, "start" to start, "duration" to durationMinutes)
            } else {
                mapOf("success" to false, "error" to "INSERT_FAILED")
            }
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun queryCalendarEvents(daysAhead: Int, query: String?): Map<String, Any> {
        if (checkSelfPermission(android.Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
            return mapOf("success" to false, "error" to "PERMISSION_DENIED", "message" to "Calendar read permission not granted.")
        }
        val list = mutableListOf<Map<String, Any>>()
        try {
            val now = System.currentTimeMillis()
            val end = now + (daysAhead * 24 * 60 * 60 * 1000L)
            val projection = arrayOf(
                CalendarContract.Events._ID,
                CalendarContract.Events.TITLE,
                CalendarContract.Events.DTSTART,
                CalendarContract.Events.DTEND,
                CalendarContract.Events.DESCRIPTION,
                CalendarContract.Events.EVENT_LOCATION
            )
            val selection = "(${CalendarContract.Events.DTSTART} >= ?) AND (${CalendarContract.Events.DTSTART} <= ?)"
            val selectionArgs = arrayOf(now.toString(), end.toString())
            val cursor = contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${CalendarContract.Events.DTSTART} ASC"
            )

            cursor?.use {
                val titleIdx = it.getColumnIndex(CalendarContract.Events.TITLE)
                val startIdx = it.getColumnIndex(CalendarContract.Events.DTSTART)
                val descIdx = it.getColumnIndex(CalendarContract.Events.DESCRIPTION)
                val locIdx = it.getColumnIndex(CalendarContract.Events.EVENT_LOCATION)

                while (it.moveToNext()) {
                    val title = if (titleIdx >= 0) it.getString(titleIdx) ?: "Untitled" else "Untitled"
                    val dtStart = if (startIdx >= 0) it.getLong(startIdx) else 0L
                    val desc = if (descIdx >= 0) it.getString(descIdx) ?: "" else ""
                    val loc = if (locIdx >= 0) it.getString(locIdx) ?: "" else ""

                    if (query == null || query.isEmpty() || title.contains(query, ignoreCase = true) || desc.contains(query, ignoreCase = true)) {
                        list.add(mapOf(
                            "title" to title,
                            "startTime" to dtStart,
                            "description" to desc,
                            "location" to loc
                        ))
                    }
                }
            }
            return mapOf("success" to true, "events" to list)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun setAlarm(hour: Int, minutes: Int, message: String): Map<String, Any> {
        try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minutes)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            val timeStr = String.format("%02d:%02d", hour, minutes)
            return mapOf("success" to true, "time" to timeStr, "message" to message)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun setTimer(seconds: Int, message: String): Map<String, Any> {
        try {
            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                putExtra(AlarmClock.EXTRA_MESSAGE, message)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            return mapOf("success" to true, "seconds" to seconds, "message" to message)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun queryContacts(query: String, limit: Int): Map<String, Any> {
        if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return mapOf("success" to false, "error" to "PERMISSION_DENIED", "message" to "Contacts read permission not granted.")
        }
        val list = mutableListOf<Map<String, String>>()
        try {
            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )
            val selection = if (query.isNotEmpty()) {
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
            } else null
            val selectionArgs = if (query.isNotEmpty()) arrayOf("%$query%") else null

            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )

            cursor?.use {
                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                var count = 0

                while (it.moveToNext() && count < limit) {
                    val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "Unknown" else "Unknown"
                    val num = if (numIdx >= 0) it.getString(numIdx) ?: "" else ""
                    list.add(mapOf("name" to name, "phone" to num))
                    count++
                }
            }
            return mapOf("success" to true, "contacts" to list)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun addContact(name: String, phone: String, email: String): Map<String, Any> {
        if (checkSelfPermission(android.Manifest.permission.WRITE_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return mapOf("success" to false, "error" to "PERMISSION_DENIED", "message" to "Contacts write permission not granted.")
        }
        try {
            val ops = ArrayList<android.content.ContentProviderOperation>()
            val rawContactInsertIndex = ops.size

            ops.add(
                android.content.ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                    .build()
            )

            // Name
            ops.add(
                android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawContactInsertIndex)
                    .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                    .build()
            )

            // Phone
            if (phone.isNotEmpty()) {
                ops.add(
                    android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawContactInsertIndex)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                        .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                        .build()
                )
            }

            // Email
            if (email.isNotEmpty()) {
                ops.add(
                    android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawContactInsertIndex)
                        .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                        .withValue(ContactsContract.CommonDataKinds.Email.DATA, email)
                        .withValue(ContactsContract.CommonDataKinds.Email.TYPE, ContactsContract.CommonDataKinds.Email.TYPE_WORK)
                        .build()
                )
            }

            contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
            return mapOf("success" to true, "name" to name, "phone" to phone, "email" to email)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun controlMedia(action: String, volume: Int?): Map<String, Any> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val act = action.uppercase().trim()
        try {
            when (act) {
                "PLAY", "PAUSE", "TOGGLE", "PLAY_PAUSE" -> {
                    val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                    val eventUp = KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                    audioManager.dispatchMediaKeyEvent(eventDown)
                    audioManager.dispatchMediaKeyEvent(eventUp)
                }
                "NEXT", "SKIP" -> {
                    val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT)
                    val eventUp = KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT)
                    audioManager.dispatchMediaKeyEvent(eventDown)
                    audioManager.dispatchMediaKeyEvent(eventUp)
                }
                "PREV", "PREVIOUS", "BACK" -> {
                    val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                    val eventUp = KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                    audioManager.dispatchMediaKeyEvent(eventDown)
                    audioManager.dispatchMediaKeyEvent(eventUp)
                }
                "STOP" -> {
                    val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP)
                    val eventUp = KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_STOP)
                    audioManager.dispatchMediaKeyEvent(eventDown)
                    audioManager.dispatchMediaKeyEvent(eventUp)
                }
                "VOLUME_UP", "UP" -> {
                    audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                }
                "VOLUME_DOWN", "DOWN" -> {
                    audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                }
                "MUTE", "TOGGLE_MUTE" -> {
                    audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_TOGGLE_MUTE, AudioManager.FLAG_SHOW_UI)
                }
                "SET_VOLUME" -> {
                    if (volume != null) {
                        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val targetVol = (volume.coerceIn(0, 100) * maxVol) / 100
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI)
                    }
                }
            }
            return mapOf("success" to true, "action" to act)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun closeApp(appName: String, packageNameArg: String): Map<String, Any> {
        try {
            var targetPkg = packageNameArg
            if (targetPkg.isEmpty() && appName.isNotEmpty()) {
                val pm = packageManager
                val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                for (pkg in packages) {
                    val label = pm.getApplicationLabel(pkg).toString()
                    if (label.contains(appName, ignoreCase = true)) {
                        targetPkg = pkg.packageName
                        break
                    }
                }
            }

            if (targetPkg.isNotEmpty()) {
                val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.killBackgroundProcesses(targetPkg)
            }

            if (AvisAccessibilityService.isServiceRunning) {
                AvisAccessibilityService.instance?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
            }

            return mapOf("success" to true, "appName" to appName, "package" to targetPkg)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun checkPermissionsState(): Map<String, Boolean> {
        val audioGranted = checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val cameraGranted = checkSelfPermission(android.Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        val smsGranted = checkSelfPermission(android.Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        val calendarGranted = checkSelfPermission(android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
        val contactsGranted = checkSelfPermission(android.Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: ""
        val notifGranted = flat.contains(packageName) || AvisNotificationService.isConnected
        val accessGranted = AvisAccessibilityService.isServiceRunning

        return mapOf(
            "audio" to audioGranted,
            "camera" to cameraGranted,
            "sms" to smsGranted,
            "calendar" to calendarGranted,
            "contacts" to contactsGranted,
            "notificationListener" to notifGranted,
            "accessibility" to accessGranted
        )
    }

    private fun controlBluetooth(action: String): Map<String, Any> {
        return try {
            val btAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                ?: return mapOf("success" to false, "error" to "No Bluetooth adapter available")
            val isEnabled = btAdapter.isEnabled
            when (action.uppercase()) {
                "ON" -> {
                    if (!isEnabled) btAdapter.enable()
                    mapOf("success" to true, "state" to "ON")
                }
                "OFF" -> {
                    if (isEnabled) btAdapter.disable()
                    mapOf("success" to true, "state" to "OFF")
                }
                "TOGGLE" -> {
                    if (isEnabled) btAdapter.disable() else btAdapter.enable()
                    mapOf("success" to true, "state" to if (isEnabled) "OFF" else "ON")
                }
                else -> mapOf("success" to true, "state" to if (isEnabled) "ON" else "OFF")
            }
        } catch (e: Exception) {
            openTargetSettings("bluetooth")
            mapOf("success" to true, "action" to "opened_settings", "message" to "Opened Bluetooth Settings")
        }
    }

    private fun controlBrightness(levelPercent: Int): Map<String, Any> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return mapOf("success" to false, "error" to "Permission WRITE_SETTINGS required. Opened Settings.")
            }
            val cl = ((levelPercent.coerceIn(0, 100) / 100.0) * 255.0).toInt().coerceIn(0, 255)
            Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE, Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
            Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, cl)
            runOnUiThread {
                try {
                    val layoutParams = window.attributes
                    layoutParams.screenBrightness = cl / 255.0f
                    window.attributes = layoutParams
                } catch (e: Exception) {}
            }
            mapOf("success" to true, "brightness" to cl, "percent" to levelPercent)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to e.message.toString())
        }
    }

    private fun openTargetSettings(target: String) {
        try {
            val intent = when (target.lowercase()) {
                "notification_listener" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                "wifi" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        Intent(Settings.Panel.ACTION_WIFI)
                    } else {
                        Intent(Settings.ACTION_WIFI_SETTINGS)
                    }
                }
                else -> {
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    )
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun computeNativePcmRms(bytes: ByteArray): Double {
        if (bytes.size < 2) return 0.0
        val numSamples = bytes.size / 2
        var sumSquares = 0.0
        val buffer = java.nio.ByteBuffer.wrap(bytes).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until numSamples) {
            val sample = buffer.short.toDouble()
            sumSquares += sample * sample
        }
        val meanSquare = sumSquares / numSamples
        val rms = Math.sqrt(meanSquare)
        if (rms < 50.0) return 0.0
        return ((rms - 50.0) / 2200.0).coerceIn(0.0, 1.0)
    }

    private fun startForegroundVoiceService() {
        try {
            VoiceForegroundService.startService(this, isMuted)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopForegroundVoiceService() {
        try {
            VoiceForegroundService.stopService(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun toggleMuteFromNotification() {
        runOnUiThread {
            isMuted = !isMuted
            audioMethodChannel?.invokeMethod("onNotificationMuteToggled", mapOf("isMuted" to isMuted))
            VoiceForegroundService.updateState(this, isMuted)
        }
    }

    fun endSessionFromNotification() {
        runOnUiThread {
            audioMethodChannel?.invokeMethod("onNotificationEndSession", null)
            stopRecording()
        }
    }

    private fun registerPhoneStateReceiver() {
        if (phoneStateReceiver != null) return
        phoneStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
                    val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                    if (state == TelephonyManager.EXTRA_STATE_RINGING || state == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                        mainHandler.post {
                            audioMethodChannel?.invokeMethod("onPhoneCallState", mapOf("active" to true))
                        }
                    } else if (state == TelephonyManager.EXTRA_STATE_IDLE) {
                        mainHandler.post {
                            audioMethodChannel?.invokeMethod("onPhoneCallState", mapOf("active" to false))
                        }
                    }
                }
            }
        }
        try {
            val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
            registerReceiver(phoneStateReceiver, filter)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getRealDeviceTelemetry(): String {
        try {
            val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
                registerReceiver(null, filter)
            }
            val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct: Int = if (level != -1 && scale != -1) (level * 100 / scale.toFloat()).toInt() else 0

            val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging: Boolean = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                    status == BatteryManager.BATTERY_STATUS_FULL

            val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memInfo = ActivityManager.MemoryInfo()
            actManager.getMemoryInfo(memInfo)
            val freeRamMb = memInfo.availMem / (1024 * 1024)
            val totalRamMb = memInfo.totalMem / (1024 * 1024)

            val stat = android.os.StatFs(filesDir.absolutePath)
            val freeStorageMb = stat.availableBytes / (1024 * 1024)
            val totalStorageMb = stat.totalBytes / (1024 * 1024)

            val connMgr = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connMgr.activeNetwork
            val caps = connMgr.getNetworkCapabilities(network)
            val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            val isCellular = caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
            val netState = when {
                isWifi -> "Wi-Fi Connected"
                isCellular -> "Cellular Mobile Data"
                else -> "Disconnected / Offline"
            }

            val deviceModel = "${Build.MANUFACTURER.uppercase()} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT})"

            val dateFormat = java.text.SimpleDateFormat("EEEE, dd MMMM yyyy, hh:mm:ss a z", java.util.Locale.getDefault())
            val currentDateTime = dateFormat.format(java.util.Date())

            return "Real Mobile Telemetry: Battery $batteryPct% [${if (isCharging) "Charging" else "Discharging"}], Net: $netState, RAM: ${freeRamMb}MB free / ${totalRamMb}MB total, Storage: ${freeStorageMb}MB free / ${totalStorageMb}MB total, Device: $deviceModel, Current DateTime: $currentDateTime."
        } catch (e: Exception) {
            return "Telemetry read error: ${e.message}"
        }
    }

    private fun openPermissionSettings(settingType: String): Map<String, Any> {
        try {
            val intent = when (settingType.uppercase()) {
                "ACCESSIBILITY" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                "OVERLAY" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                "USAGE_STATS" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                "NOTIFICATION" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                "APP_DETAILS", "PERMISSIONS" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                else -> Intent(Settings.ACTION_SETTINGS)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            return mapOf("success" to true, "message" to "Opened Android Settings ($settingType)")
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to "Could not open settings ($settingType): ${e.message}")
        }
    }

    private fun sendWhatsAppMessage(phone: String, message: String): Map<String, Any> {
        try {
            val cleanPhone = phone.replace(Regex("[^0-9+]"), "")
            val encodedMessage = Uri.encode(message)
            val url = if (cleanPhone.isNotEmpty()) {
                "https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMessage"
            } else {
                "https://api.whatsapp.com/send?text=$encodedMessage"
            }
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                intent.`package` = "com.whatsapp"
                startActivity(intent)
            } catch (e: Exception) {
                val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
            }
            val targetDesc = if (cleanPhone.isNotEmpty()) "to $cleanPhone" else ""
            return mapOf("success" to true, "message" to "WhatsApp opened $targetDesc with message.")
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to "Could not open WhatsApp: ${e.message}")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                val serviceIntent = Intent(this, ScreenCastService::class.java).apply {
                    action = ScreenCastService.ACTION_START
                    putExtra(ScreenCastService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCastService.EXTRA_RESULT_DATA, data)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } else {
                screenEventSink?.error("PERMISSION_DENIED", "Screen capture permission denied by user", null)
            }
        }
    }

    private fun startScreenCastPermissionRequest(): Boolean {
        try {
            if (mediaProjectionManager == null) {
                mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            }
            val intent = mediaProjectionManager?.createScreenCaptureIntent()
            if (intent != null) {
                startActivityForResult(intent, SCREEN_CAPTURE_REQUEST_CODE)
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    fun onProjectionError(code: String, message: String) {
        mainHandler.post {
            isScreenCasting.set(false)
            screenEventSink?.error(code, message, null)
        }
    }

    fun startScreenProjectionWithMediaProjection(projection: MediaProjection) {
        mainHandler.post {
            try {
                mediaProjection = projection

                // Register MediaProjection.Callback for Android 14+ session lifecycle
                mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        mainHandler.post {
                            stopScreenCast()
                            screenEventSink?.error("PROJECTION_STOPPED", "Screen capture session ended by system", null)
                        }
                    }
                }, mainHandler)

                screenCaptureWorkerThread = HandlerThread("ScreenCaptureWorker").apply { start() }
                screenCaptureHandler = Handler(screenCaptureWorkerThread!!.looper)

                val metrics = resources.displayMetrics
                val width = 720
                val height = (metrics.heightPixels.toFloat() / metrics.widthPixels.toFloat() * width).toInt()
                val density = metrics.densityDpi

                imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
                virtualDisplay = mediaProjection?.createVirtualDisplay(
                    "AvisScreenCapture",
                    width,
                    height,
                    density,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    imageReader?.surface,
                    null,
                    null
                )

                isScreenCasting.set(true)

                imageReader?.setOnImageAvailableListener({ reader ->
                    val now = System.currentTimeMillis()
                    if (now - lastFrameTime < 650) {
                        val img = reader.acquireLatestImage()
                        img?.close()
                        return@setOnImageAvailableListener
                    }
                    lastFrameTime = now

                    val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                    val planes = image.planes
                    val buffer = planes[0].buffer
                    val pixelStride = planes[0].pixelStride
                    val rowStride = planes[0].rowStride
                    val rowPadding = rowStride - pixelStride * width

                    val bitmap = Bitmap.createBitmap(
                        width + rowPadding / pixelStride,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.copyPixelsFromBuffer(buffer)
                    image.close()

                    val croppedBitmap = if (rowPadding > 0) {
                        Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    } else {
                        bitmap
                    }

                    val stream = ByteArrayOutputStream()
                    croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 60, stream)
                    val jpegBytes = stream.toByteArray()

                    if (croppedBitmap != bitmap) {
                        bitmap.recycle()
                    }
                    croppedBitmap.recycle()

                    // Only EventSink.success() must be posted to main thread (Flutter requirement)
                    mainHandler.post {
                        screenEventSink?.success(jpegBytes)
                    }
                }, screenCaptureHandler)

            } catch (e: Exception) {
                e.printStackTrace()
                stopScreenCast()
                mainHandler.post {
                    screenEventSink?.error("CAPTURE_INIT_FAILED", "Screen capture failed: ${e.message}", null)
                }
            }
        }
    }

    private fun stopScreenCast() {
        try {
            isScreenCasting.set(false)
            virtualDisplay?.release()
            virtualDisplay = null
            imageReader?.close()
            imageReader = null
            mediaProjection?.stop()
            mediaProjection = null

            // Clean up background worker thread
            screenCaptureWorkerThread?.quitSafely()
            screenCaptureWorkerThread = null
            screenCaptureHandler = null

            val serviceIntent = Intent(this, ScreenCastService::class.java).apply {
                action = ScreenCastService.ACTION_STOP
            }
            startService(serviceIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Minimize app to background without destroying the activity or terminating voice session
        moveTaskToBack(true)
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
        stopScreenCast()
        stopRecording()
        isPlaying.set(false)
        audioQueue.clear()
        try {
            playbackThread?.interrupt()
            playbackThread = null
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}
