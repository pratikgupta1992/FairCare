package com.faircare.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faircare.app.ui.theme.FairCareTheme
import java.io.File
import java.util.Date

/**
 * Shown (in a separate process) when the app crashes. Displays the stack
 * trace so it can be screenshotted, and saves it to a file.
 * Temporary debugging aid — remove once the crash is fixed.
 */
class CrashActivity : ComponentActivity() {
    companion object {
        const val EXTRA_TRACE = "trace"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trace = intent.getStringExtra(EXTRA_TRACE) ?: "no trace captured"
        var savedPath by mutableStateOf("saving...")
        try {
            val f = File(getExternalFilesDir(null), "faircare-crash.txt")
            f.writeText("FairCare crash ${Date()}\n\n$trace")
            savedPath = f.absolutePath
        } catch (e: Exception) {
            savedPath = "could not save file: $e"
        }
        setContent {
            FairCareTheme {
                Column(
                    Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                        .verticalScroll(rememberScrollState())
                ) {
                    Text("FairCare crashed", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Please take a screenshot of this page and send it — it shows exactly what went wrong.",
                        fontSize = 14.sp
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Trace also saved to:",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        savedPath,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(trace, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}
