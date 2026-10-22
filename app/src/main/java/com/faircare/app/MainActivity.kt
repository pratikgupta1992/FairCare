package com.faircare.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.faircare.app.ui.FairViewModel
import com.faircare.app.ui.screens.AnalyticsScreen
import com.faircare.app.ui.screens.CalendarScreen
import com.faircare.app.ui.screens.ManageScreen
import com.faircare.app.ui.screens.TodayScreen
import com.faircare.app.ui.theme.FairCareTheme

class MainActivity : ComponentActivity() {
    private val vm: FairViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        installCrashReporter()
        super.onCreate(savedInstanceState)
        val openLog = intent?.getBooleanExtra(
            com.faircare.app.notify.ReminderScheduler.EXTRA_OPEN_LOG, false
        ) == true
        setContent {
            FairCareTheme {
                var tab by remember { mutableStateOf(0) }
                Scaffold(
                    bottomBar = {
                        NavigationBar {
                            NavigationBarItem(
                                selected = tab == 0,
                                onClick = { tab = 0 },
                                icon = { Icon(Icons.Default.Schedule, contentDescription = null) },
                                label = { Text("Today") }
                            )
                            NavigationBarItem(
                                selected = tab == 1,
                                onClick = { tab = 1 },
                                icon = { Icon(Icons.Default.CalendarMonth, contentDescription = null) },
                                label = { Text("Calendar") }
                            )
                            NavigationBarItem(
                                selected = tab == 2,
                                onClick = { tab = 2 },
                                icon = { Icon(Icons.Default.BarChart, contentDescription = null) },
                                label = { Text("Analytics") }
                            )
                            NavigationBarItem(
                                selected = tab == 3,
                                onClick = { tab = 3 },
                                icon = { Icon(Icons.Default.Settings, contentDescription = null) },
                                label = { Text("Manage") }
                            )
                        }
                    }
                ) { pad ->
                    androidx.compose.foundation.layout.Box(Modifier.padding(pad)) {
                        when (tab) {
                            0 -> TodayScreen(vm, autoOpenLog = openLog)
                            1 -> CalendarScreen(vm, onJumpToDay = { vm.jumpToDay(it); tab = 0 })
                            2 -> AnalyticsScreen(vm)
                            3 -> ManageScreen(vm)
                        }
                    }
                }
            }
        }
    }

    /**
     * Temporary debugging aid: on any uncaught crash, launch CrashActivity in a
     * separate process to display (and save) the stack trace, then die as usual.
     * Remove once the crash is fixed.
     */
    private fun installCrashReporter() {
        val default = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, e ->
            try {
                val sw = java.io.StringWriter()
                e.printStackTrace(java.io.PrintWriter(sw))
                val trace = "$e\n$sw".take(12000)
                startActivity(
                    android.content.Intent(this, CrashActivity::class.java).apply {
                        putExtra(CrashActivity.EXTRA_TRACE, trace)
                        addFlags(
                            android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                                android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK
                        )
                    }
                )
            } catch (_: Exception) {
            }
            // Brief pause so the crash screen can launch before this process dies.
            try {
                Thread.sleep(800)
            } catch (_: Exception) {
            }
            try {
                default?.uncaughtException(thread, e)
            } catch (_: Exception) {
            }
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }
}
