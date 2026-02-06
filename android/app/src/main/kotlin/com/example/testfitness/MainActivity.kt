package com.example.testfitness

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.AudioAttributes
import android.media.AudioManager.OnAudioFocusChangeListener

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.testfitness/vibration"
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    
    // Audio focus change listener
    private val afChangeListener = OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                // We've lost focus, but we don't care for timer sounds
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                // We've gained focus
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize audio manager
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = call.argument<Int>("duration") ?: 500
                    vibrate(duration.toLong())
                    result.success(true)
                }
                "requestAudioFocus" -> {
                    val success = requestAudioFocus()
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun requestAudioFocus(): Boolean {
        audioManager?.let { am ->
            // Request audio focus for notification sounds
            val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // For API 26+
                val playbackAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(playbackAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener(afChangeListener)
                    .build()
                
                am.requestAudioFocus(audioFocusRequest!!)
            } else {
                // For API < 26
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    afChangeListener,
                    AudioManager.STREAM_NOTIFICATION,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }
            
            return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        
        return false
    }
    
    private fun vibrate(duration: Long) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
