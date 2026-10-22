package com.faircare.app.ui.screens

import android.Manifest
import android.app.TimePickerDialog
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.faircare.app.data.Baby
import com.faircare.app.data.CareTask
import com.faircare.app.data.Caregiver
import com.faircare.app.data.CaregiverType
import com.faircare.app.data.Eligibility
import com.faircare.app.data.ReminderPrefs
import com.faircare.app.notify.ReminderScheduler
import com.faircare.app.ui.FairViewModel
import com.faircare.app.ui.components.PALETTE
import kotlin.math.roundToInt

@Composable
fun ManageScreen(vm: FairViewModel) {
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("Babies", "Caregivers", "Tasks", "Settings")
    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = {
                when (tab) {
                    0 -> showBabyDialog = true
                    1 -> showCgDialog = true
                    2 -> editTask = TaskEdit()
                }
            }) { Icon(Icons.Default.Add, contentDescription = "Add") }
        }
    ) { pad ->
        Column(Modifier.fillMaxSize().padding(pad)) {
            TabRow(selectedTabIndex = tab) {
                tabs.forEachIndexed { i, t ->
                    Tab(selected = tab == i, onClick = { tab = i }, text = { Text(t) })
                }
            }
            when (tab) {
                0 -> BabiesTab(vm)
                1 -> CaregiversTab(vm)
                2 -> TasksTab(vm)
                3 -> SettingsTab()
            }
        }
    }

    if (showBabyDialog) {
        BabyDialog(onDismiss = { showBabyDialog = false }, onSave = { n, c ->
            vm.addBaby(n, c); showBabyDialog = false
        })
    }
    if (showCgDialog) {
        CaregiverDialog(onDismiss = { showCgDialog = false }, onSave = { n, t, c ->
            vm.addCaregiver(n, t, c); showCgDialog = false
        })
    }
    val et = editTask
    if (et != null) {
        TaskDialog(
            initial = et.task,
            onDismiss = { editTask = null },
            onSave = { name, emoji, weight, elig, counts ->
                if (et.task == null) vm.addTask(name, emoji, weight, elig, counts)
                else vm.updateTask(et.task.copy(name = name, emoji = emoji, weight = weight, eligibility = elig, countsTowardBalance = counts))
                editTask = null
            },
            onDelete = et.task?.let { t ->
                { vm.deleteTask(t); editTask = null }
            }
        )
    }
}

// dialog visibility holders (module-level for simplicity)
private var showBabyDialog by mutableStateOf(false)
private var showCgDialog by mutableStateOf(false)
private data class TaskEdit(val task: CareTask? = null)
private var editTask by mutableStateOf<TaskEdit?>(null)

@Composable
private fun BabiesTab(vm: FairViewModel) {
    val babies by vm.babies.collectAsState(initial = emptyList())
    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        items(babies) { b ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(20.dp).clip(CircleShape).background(Color(b.color)))
                Spacer(Modifier.width(12.dp))
                Text(b.name, Modifier.weight(1f), fontSize = 16.sp)
                IconButton(onClick = { vm.deleteBaby(b) }) {
                    Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}

@Composable
private fun CaregiversTab(vm: FairViewModel) {
    val caregivers by vm.caregivers.collectAsState(initial = emptyList())
    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        items(caregivers) { c ->
            Row(
                Modifier.fillMaxWidth().padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.size(20.dp).clip(CircleShape).background(Color(c.color)))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(c.name, fontSize = 16.sp)
                    Text(
                        c.type.label + if (c.type.isPaidExternal) " · paid help" else "",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = { vm.deleteCaregiver(c) }) {
                    Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                }
            }
        }
        item {
            Spacer(Modifier.height(8.dp))
            Text(
                "Nanny/daycare time is tracked separately so paid help never masks the Mom–Dad split.",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun TasksTab(vm: FairViewModel) {
    val tasks by vm.tasks.collectAsState(initial = emptyList())
    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        items(tasks) { t ->
            Row(
                Modifier.fillMaxWidth()
                    .clickable { editTask = TaskEdit(t) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(t.emoji, fontSize = 24.sp)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(t.name, fontSize = 15.sp, fontWeight = FontWeight.Medium)
                    Text(
                        "${t.eligibility.label} · ${t.weight}×" +
                            (if (!t.countsTowardBalance) " · excluded from score" else ""),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Icon(Icons.Default.Edit, contentDescription = "Edit", tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        item {
            Spacer(Modifier.height(8.dp))
            Card { 
                Text(
                    "Task rules: weight multiplies the minutes (night hours 10pm–6am count 1.5× on top). " +
                        "Mom-only tasks (breastfeeding, pumping) can only be logged for Mom and count fully toward her share — " +
                        "so Dad supervising during a pump session never looks 'balanced'.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(12.dp)
                )
            }
        }
    }
}

@Composable
private fun SettingsTab() {
    val ctx = LocalContext.current
    val appCtx = ctx.applicationContext
    val prefs = remember { ReminderPrefs(appCtx) }
    var enabled by remember { mutableStateOf(prefs.enabled) }
    var quietStart by remember { mutableStateOf(prefs.quietStartMin) }
    var quietEnd by remember { mutableStateOf(prefs.quietEndMin) }
    var showPermNote by remember { mutableStateOf(false) }

    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            prefs.enabled = true
            enabled = true
            showPermNote = false
            ReminderScheduler.ensureChannel(appCtx)
            ReminderScheduler.schedule(appCtx)
        } else {
            showPermNote = true
        }
    }

    fun setEnabled(on: Boolean) {
        if (on) {
            if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(
                    appCtx, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                permLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                prefs.enabled = true
                enabled = true
                ReminderScheduler.ensureChannel(appCtx)
                ReminderScheduler.schedule(appCtx)
            }
        } else {
            prefs.enabled = false
            enabled = false
            showPermNote = false
            ReminderScheduler.cancel(appCtx)
        }
    }

    fun pickTime(current: Int, onPick: (Int) -> Unit) {
        TimePickerDialog(
            ctx,
            { _, h, m -> onPick(h * 60 + m) },
            current / 60, current % 60, false
        ).show()
    }

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Reminders", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text("Hourly logging reminders", fontSize = 16.sp)
                Text(
                    "A gentle nudge each hour to log who's caring for the baby. " +
                        "Skips hours you've already logged.",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(Modifier.width(12.dp))
            Switch(checked = enabled, onCheckedChange = ::setEnabled)
        }
        if (showPermNote && !enabled) {
            Spacer(Modifier.height(8.dp))
            Text(
                "Notifications are turned off for FairCare, so reminders can't appear. " +
                    "Enable them in system Settings → Apps → FairCare → Notifications, " +
                    "then turn reminders on again.",
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.error
            )
        }
        Spacer(Modifier.height(20.dp))
        Text("Quiet hours", fontWeight = FontWeight.Medium, fontSize = 16.sp)
        Text(
            "No reminders during these hours.",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = {
                pickTime(quietStart) { v -> quietStart = v; prefs.quietStartMin = v }
            }) { Text(ReminderPrefs.fmt(quietStart), fontSize = 17.sp) }
            Text("  –  ", fontSize = 17.sp)
            TextButton(onClick = {
                pickTime(quietEnd) { v -> quietEnd = v; prefs.quietEndMin = v }
            }) { Text(ReminderPrefs.fmt(quietEnd), fontSize = 17.sp) }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            "Defaults to 10:00 PM – 7:00 AM. Tap a time to change it.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ColorPicker(selected: Int, onPick: (Int) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        PALETTE.forEach { c ->
            Box(
                Modifier.size(32.dp).clip(CircleShape)
                    .background(Color(c))
                    .clickable { onPick(c) }
                    .padding(2.dp)
            ) {
                if (c == selected) {
                    Box(
                        Modifier.size(12.dp).clip(CircleShape)
                            .background(Color.White)
                            .align(Alignment.Center)
                    )
                }
            }
        }
    }
}

@Composable
private fun BabyDialog(onDismiss: () -> Unit, onSave: (String, Int) -> Unit) {
    var name by remember { mutableStateOf("") }
    var color by remember { mutableStateOf(PALETTE[2]) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add baby") },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                Spacer(Modifier.height(12.dp))
                ColorPicker(color) { color = it }
            }
        },
        confirmButton = {
            TextButton(onClick = { if (name.isNotBlank()) onSave(name.trim(), color) }) { Text("Add") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CaregiverDialog(onDismiss: () -> Unit, onSave: (String, CaregiverType, Int) -> Unit) {
    var name by remember { mutableStateOf("") }
    var type by remember { mutableStateOf(CaregiverType.FAMILY) }
    var color by remember { mutableStateOf(PALETTE[4]) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add caregiver") },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                Spacer(Modifier.height(12.dp))
                Text("Type", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(4.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CaregiverType.values().forEach { t ->
                        FilterChip(
                            selected = type == t,
                            onClick = { type = t },
                            label = { Text(t.label) }
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                ColorPicker(color) { color = it }
            }
        },
        confirmButton = {
            TextButton(onClick = { if (name.isNotBlank()) onSave(name.trim(), type, color) }) { Text("Add") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TaskDialog(
    initial: CareTask?,
    onDismiss: () -> Unit,
    onSave: (String, String, Float, Eligibility, Boolean) -> Unit,
    onDelete: (() -> Unit)?
) {
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var emoji by remember { mutableStateOf(initial?.emoji ?: "⭐") }
    var weight by remember { mutableStateOf(initial?.weight ?: 1f) }
    var eligibility by remember { mutableStateOf(initial?.eligibility ?: Eligibility.ANYONE) }
    var counts by remember { mutableStateOf(initial?.countsTowardBalance ?: true) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "Add task" else "Edit task") },
        text = {
            Column {
                Row {
                    OutlinedTextField(
                        emoji, { if (it.length <= 4) emoji = it },
                        label = { Text("Emoji") }, singleLine = true,
                        modifier = Modifier.weight(0.35f)
                    )
                    Spacer(Modifier.width(8.dp))
                    OutlinedTextField(
                        name, { name = it },
                        label = { Text("Task name") }, singleLine = true,
                        modifier = Modifier.weight(0.65f)
                    )
                }
                Spacer(Modifier.height(8.dp))
                Text("Effort weight: ${"%.1f".format(weight)}×", fontSize = 13.sp)
                Slider(
                    value = weight, onValueChange = { weight = (it * 10).roundToInt() / 10f },
                    valueRange = 0.5f..2.5f
                )
                Text("Who can do it", fontSize = 13.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Eligibility.values().forEach { e ->
                        androidx.compose.material3.FilterChip(
                            selected = eligibility == e,
                            onClick = { eligibility = e },
                            label = { Text(e.label) }
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(counts, { counts = it })
                    Text("Counts toward fairness score", fontSize = 13.sp)
                }
                if (onDelete != null) {
                    TextButton(onClick = onDelete) {
                        Text("Delete task", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) onSave(name.trim(), emoji.ifBlank { "⭐" }, weight, eligibility, counts)
                }
            ) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}
