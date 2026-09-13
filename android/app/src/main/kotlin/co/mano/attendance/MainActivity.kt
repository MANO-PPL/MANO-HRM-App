package co.mano.attendance

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.MotionEvent
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "co.mano.attendance/settings"
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private var isNavBarVisible = false
    private val navBarHandler = Handler(Looper.getMainLooper())
    private val autoHideRunnable = Runnable {
        hideSystemNavigationBar()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideSystemNavigationBar()

        ViewCompat.setOnApplyWindowInsetsListener(window.decorView) { v, insets ->
            val navVisible = insets.isVisible(WindowInsetsCompat.Type.navigationBars())
            if (navVisible) {
                isNavBarVisible = true
                scheduleAutoHide()
            } else {
                isNavBarVisible = false
                navBarHandler.removeCallbacks(autoHideRunnable)
            }
            ViewCompat.onApplyWindowInsets(v, insets)
        }

        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
                val navVisible = (visibility and View.SYSTEM_UI_FLAG_HIDE_NAVIGATION) == 0
                if (navVisible) {
                    isNavBarVisible = true
                    scheduleAutoHide()
                } else {
                    isNavBarVisible = false
                    navBarHandler.removeCallbacks(autoHideRunnable)
                }
            }
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev?.action == MotionEvent.ACTION_DOWN) {
            val insets = ViewCompat.getRootWindowInsets(window.decorView)
            val isVisible = insets?.isVisible(WindowInsetsCompat.Type.navigationBars()) ?: isNavBarVisible
            if (isVisible) {
                hideSystemNavigationBar()
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemNavigationBar()
        }
    }

    private fun scheduleAutoHide() {
        navBarHandler.removeCallbacks(autoHideRunnable)
        navBarHandler.postDelayed(autoHideRunnable, 5000) // 5 seconds auto close
    }

    private fun hideSystemNavigationBar() {
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        windowInsetsController.hide(WindowInsetsCompat.Type.navigationBars())

        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }

        isNavBarVisible = false
        navBarHandler.removeCallbacks(autoHideRunnable)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openNetworkSettings") {
                try {
                    val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val intent = Intent(Settings.ACTION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (ex: Exception) {
                        result.error("UNAVAILABLE", "Settings not available", null)
                    }
                }
            } else if (call.method == "hideNavigationBar") {
                hideSystemNavigationBar()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "co.mano.attendance/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundTask" -> {
                    try {
                        val powerManager = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                        if (wakeLock == null) {
                            wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "AttendanceApp::BackgroundUpload")
                        }
                        if (wakeLock?.isHeld == false) {
                            wakeLock?.acquire(30000) // 30 seconds max timeout
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                "endBackgroundTask" -> {
                    try {
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        wakeLock = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
