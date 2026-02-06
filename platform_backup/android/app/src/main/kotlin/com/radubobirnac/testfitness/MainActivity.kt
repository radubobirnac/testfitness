package com.radubobirnac.testfitness

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            Log.d("MainActivity", "Starting onCreate")
            super.onCreate(savedInstanceState)
            Log.d("MainActivity", "Successfully completed onCreate")
        } catch (e: Exception) {
            // Log the error including stacktrace
            Log.e("MainActivity", "Error in onCreate: ${e.message}", e)
            e.stackTrace.forEach {
                Log.e("MainActivity", "StackTrace: $it")
            }

            // Show a toast message
            try {
                Toast.makeText(
                    this,
                    "Error starting app: ${e.message}",
                    Toast.LENGTH_LONG
                ).show()
            } catch (toastError: Exception) {
                Log.e("MainActivity", "Error showing toast", toastError)
            }
        }
    }
}
