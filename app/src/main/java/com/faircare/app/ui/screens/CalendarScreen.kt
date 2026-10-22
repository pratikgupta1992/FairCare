package com.faircare.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faircare.app.data.Caregiver
import com.faircare.app.data.CareTask
import com.faircare.app.data.LogEntry
import com.faircare.app.logic.computeFairness
import com.faircare.app.ui.FairViewModel
import com.faircare.app.ui.components.BabyChips
import com.faircare.app.ui.components.ScoreRing
import com.faircare.app.ui.components.SplitBar
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

private const val DAY_MILLIS = 24 * 3_600_000L
private val MONTHS = listOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
)

private enum class CalMode(val label: String) {
    MONTH("Month"), YEAR("Year"), LIFETIME("Lifetime")
}

@Composable
fun CalendarScreen(vm: FairViewModel, onJumpToDay: (Long) -> Unit) {
    val babies by vm.babies.collectAsState(initial = emptyList())
    val caregivers by vm.caregivers.collectAsState(initial = emptyList())
    val tasks by vm.tasks.collectAsState(initial = emptyList())
    var mode by remember { mutableStateOf(CalMode.MONTH) }
    // shared with YearView so tapping a month jumps straight to it
    var monthCursor by remember { mutableStateOf(monthStart(System.currentTimeMillis())) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
    ) {
        Spacer(Modifier.height(8.dp))
        BabyChips(babies, vm.selectedBabyId, { vm.selectedBabyId = it })
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CalMode.values().forEach { m ->
                FilterChip(
                    selected = mode == m,
                    onClick = { mode = m },
                    label = { Text(m.label) }
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        when (mode) {
            CalMode.MONTH -> MonthView(
                vm = vm,
                caregivers = caregivers,
                tasks = tasks,
                monthCursor = monthCursor,
                onCursor = { monthCursor = it },
                onJumpToDay = onJumpToDay
            )
            CalMode.YEAR -> YearView(
                vm = vm,
                caregivers = caregivers,
                tasks = tasks,
                onPickMonth = { monthCursor = it; mode = CalMode.MONTH }
            )
            CalMode.LIFETIME -> LifetimeView(
                vm = vm,
                caregivers = caregivers,
                tasks = tasks
            )
        }
        Spacer(Modifier.height(80.dp))
    }
}

// ---------------------------------------------------------------------------
// Month
// ---------------------------------------------------------------------------

@Composable
private fun MonthView(
    vm: FairViewModel,
    caregivers: List<Caregiver>,
    tasks: List<CareTask>,
    monthCursor: Long,
    onCursor: (Long) -> Unit,
    onJumpToDay: (Long) -> Unit
) {
    val monthEnd = addMonths(monthCursor, 1)
    val entries by vm.logsFlow(monthCursor, monthEnd, vm.selectedBabyId)
        .collectAsState(initial = emptyList())
    val taskById = tasks.associateBy { it.id }
    val cgById = caregivers.associateBy { it.id }
    var selectedDay by remember(monthCursor) { mutableStateOf<Long?>(null) }

    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        IconButton(onClick = { onCursor(addMonths(monthCursor, -1)) }) {
            Icon(Icons.Default.ChevronLeft, contentDescription = "Previous month")
        }
        Text(monthTitle(monthCursor), fontWeight = FontWeight.Bold, fontSize = 18.sp)
        IconButton(onClick = { onCursor(addMonths(monthCursor, 1)) }) {
            Icon(Icons.Default.ChevronRight, contentDescription = "Next month")
        }
    }

    val report = remember(entries) { computeFairness(entries, taskById, cgById) }
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            ScoreRing(report.score, size = 72.dp)
            Spacer(Modifier.padding(8.dp))
            Column {
                Text(report.verdict, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                Text(
                    "${report.totalMinutes / 60}h ${report.totalMinutes % 60}m logged this month",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
    }
    Spacer(Modifier.height(12.dp))

    Row(Modifier.fillMaxWidth()) {
        listOf("S", "M", "T", "W", "T", "F", "S").forEach {
            Text(
                it,
                Modifier.weight(1f),
                textAlign = TextAlign.Center,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.Medium
            )
        }
    }
    Spacer(Modifier.height(4.dp))
    val cells = remember(monthCursor) { monthCells(monthCursor) }
    cells.chunked(7).forEach { week ->
        Row(Modifier.fillMaxWidth()) {
            week.forEach { dayStart ->
                Box(Modifier.weight(1f)) {
                    if (dayStart == null) {
                        Spacer(Modifier.aspectRatio(1f).fillMaxWidth())
                    } else {
                        val dayEntries = entries.filter {
                            it.startMillis >= dayStart && it.startMillis < dayStart + DAY_MILLIS
                        }
                        val score = remember(dayEntries) {
                            if (dayEntries.isEmpty()) null
                            else computeFairness(dayEntries, taskById, cgById).score
                        }
                        DayCell(
                            dayStart = dayStart,
                            score = score,
                            hasLogs = dayEntries.isNotEmpty(),
                            selected = selectedDay == dayStart,
                            onClick = { selectedDay = dayStart }
                        )
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(12.dp))

    selectedDay?.let { ds ->
        val dayEntries = entries.filter {
            it.startMillis >= ds && it.startMillis < ds + DAY_MILLIS
        }
        val dayReport = remember(dayEntries) { computeFairness(dayEntries, taskById, cgById) }
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ScoreRing(dayReport.score, size = 56.dp)
                    Spacer(Modifier.padding(8.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            SimpleDateFormat("EEEE, MMM d", Locale.US).format(Date(ds)),
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                        Text(
                            dayReport.verdict,
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                // per-caregiver minutes
                val minsByCg = dayEntries.groupBy { it.caregiverId }
                    .mapValues { (_, es) -> es.sumOf { it.durationMin } }
                    .toList().sortedByDescending { it.second }
                minsByCg.forEach { (cgId, mins) ->
                    val cg = cgById[cgId]
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            Modifier
                                .padding(end = 8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(cg?.let { Color(it.color) } ?: Color.Gray)
                                .padding(horizontal = 8.dp, vertical = 2.dp)
                        ) {
                            Text(
                                cg?.name ?: "?",
                                fontSize = 12.sp,
                                color = Color.White,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        Text(
                            "${mins / 60}h ${mins % 60}m",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                if (dayEntries.isEmpty()) {
                    Text(
                        "Nothing logged this day.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = { onJumpToDay(ds) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("Open in Today view") }
            }
        }
    }
}

@Composable
private fun DayCell(
    dayStart: Long,
    score: Double?,
    hasLogs: Boolean,
    selected: Boolean,
    onClick: () -> Unit
) {
    val cal = remember(dayStart) {
        Calendar.getInstance().apply { timeInMillis = dayStart }
    }
    val isTodayDay = dayStart == startOfDayLocal(System.currentTimeMillis())
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .padding(2.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(
                when {
                    selected -> MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)
                    score != null -> scoreTint(score)
                    else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                }
            )
            .clickable(onClick = onClick)
            .padding(4.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${cal.get(Calendar.DAY_OF_MONTH)}",
                fontSize = 14.sp,
                fontWeight = if (isTodayDay) FontWeight.Bold else FontWeight.Normal,
                color = if (isTodayDay) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.onSurface
            )
            Text(
                if (hasLogs && score != null) "${score.roundToInt()}" else "·",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun scoreTint(score: Double): Color = when {
    score >= 80 -> Color(0xFFC8E6C9)
    score >= 60 -> Color(0xFFFFF9C4)
    score >= 40 -> Color(0xFFFFE0B2)
    else -> Color(0xFFFFCDD2)
}

// ---------------------------------------------------------------------------
// Year
// ---------------------------------------------------------------------------

@Composable
private fun YearView(
    vm: FairViewModel,
    caregivers: List<Caregiver>,
    tasks: List<CareTask>,
    onPickMonth: (Long) -> Unit
) {
    var yearCursor by remember { mutableStateOf(yearStart(System.currentTimeMillis())) }
    val yearEnd = addYears(yearCursor, 1)
    val entries by vm.logsFlow(yearCursor, yearEnd, vm.selectedBabyId)
        .collectAsState(initial = emptyList())
    val taskById = tasks.associateBy { it.id }
    val cgById = caregivers.associateBy { it.id }
    val year = remember(yearCursor) {
        Calendar.getInstance().apply { timeInMillis = yearCursor }.get(Calendar.YEAR)
    }

    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        IconButton(onClick = { yearCursor = addYears(yearCursor, -1) }) {
            Icon(Icons.Default.ChevronLeft, contentDescription = "Previous year")
        }
        Text("$year", fontWeight = FontWeight.Bold, fontSize = 18.sp)
        IconButton(onClick = { yearCursor = addYears(yearCursor, 1) }) {
            Icon(Icons.Default.ChevronRight, contentDescription = "Next year")
        }
    }
    Spacer(Modifier.height(4.dp))

    val byMonth = remember(entries, yearCursor) {
        (0 until 12).map { m ->
            val ms = addMonths(yearCursor, m)
            val me = addMonths(yearCursor, m + 1)
            val es = entries.filter { it.startMillis >= ms && it.startMillis < me }
            Triple(ms, es, computeFairness(es, taskById, cgById))
        }
    }
    byMonth.chunked(3).forEach { row ->
        Row(Modifier.fillMaxWidth()) {
            row.forEach { (ms, es, rep) ->
                val mins = es.sumOf { it.durationMin }
                Box(
                    Modifier
                        .weight(1f)
                        .padding(4.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            if (es.isEmpty()) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
                            else scoreTint(rep.score ?: 0.0)
                        )
                        .clickable { onPickMonth(ms) }
                        .padding(10.dp)
                ) {
                    Column {
                        Text(
                            MONTHS[Calendar.getInstance().apply { timeInMillis = ms }
                                .get(Calendar.MONTH)].take(3),
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            if (es.isEmpty()) "no logs"
                            else "${rep.score?.roundToInt() ?: "–"} · ${mins / 60}h",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
    Spacer(Modifier.height(8.dp))
    Text(
        "Tap a month to see its days.",
        fontSize = 12.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

// ---------------------------------------------------------------------------
// Lifetime
// ---------------------------------------------------------------------------

@Composable
private fun LifetimeView(
    vm: FairViewModel,
    caregivers: List<Caregiver>,
    tasks: List<CareTask>
) {
    val entries by vm.logsFlow(0, System.currentTimeMillis() + DAY_MILLIS, vm.selectedBabyId)
        .collectAsState(initial = emptyList())
    val taskById = tasks.associateBy { it.id }
    val cgById = caregivers.associateBy { it.id }
    val report = remember(entries) { computeFairness(entries, taskById, cgById) }

    val daysLogged = remember(entries) {
        entries.map { startOfDayLocal(it.startMillis) }.toSet().size
    }
    val firstLog = remember(entries) { entries.minOfOrNull { it.startMillis } }

    Text("Lifetime", fontWeight = FontWeight.Bold, fontSize = 18.sp)
    Spacer(Modifier.height(8.dp))
    Card(
        Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
    ) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            ScoreRing(report.score, size = 88.dp)
            Spacer(Modifier.padding(8.dp))
            Column {
                Text(report.verdict, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(Modifier.height(4.dp))
                Text(
                    "${report.totalMinutes / 60}h ${report.totalMinutes % 60}m of care across $daysLogged days",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                if (firstLog != null) {
                    Text(
                        "Logging since ${SimpleDateFormat("MMM d, yyyy", Locale.US).format(Date(firstLog))}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                if (report.outsourcedShare > 0.01) {
                    Text(
                        "Nanny/daycare: ${(report.outsourcedShare * 100).roundToInt()}% of all care",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }
        }
    }
    Spacer(Modifier.height(12.dp))

    if (report.parentShare.isNotEmpty()) {
        Text("All-time parental share", fontWeight = FontWeight.Bold, fontSize = 15.sp)
        Spacer(Modifier.height(6.dp))
        SplitBar(
            report.parentShare.map { (cgId, share) ->
                val cg = cgById[cgId]
                Triple(cg?.name ?: "?", cg?.let { Color(it.color) } ?: Color.Gray, share)
            }
        )
        Spacer(Modifier.height(12.dp))
    }

    // all-time per-caregiver hours (everyone, incl. nanny/daycare)
    val minsByCg = remember(entries) {
        entries.groupBy { it.caregiverId }
            .mapValues { (_, es) -> es.sumOf { it.durationMin } }
            .toList().sortedByDescending { it.second }
    }
    if (minsByCg.isNotEmpty()) {
        Text("Hours by caregiver", fontWeight = FontWeight.Bold, fontSize = 15.sp)
        Spacer(Modifier.height(6.dp))
        val maxMins = minsByCg.maxOf { it.second }.coerceAtLeast(1)
        minsByCg.forEach { (cgId, mins) ->
            val cg = cgById[cgId]
            Row(
                Modifier.fillMaxWidth().padding(vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    cg?.name ?: "?",
                    Modifier.weight(1f),
                    fontSize = 13.sp
                )
                Box(
                    Modifier
                        .weight(1f)
                        .height(10.dp)
                        .clip(RoundedCornerShape(5.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Box(
                        Modifier
                            .fillMaxHeight()
                            .fillMaxWidth((mins.toFloat() / maxMins).coerceIn(0f, 1f))
                            .background(cg?.let { Color(it.color) } ?: Color.Gray)
                    )
                }
                Text(
                    "${mins / 60}h",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// date helpers
// ---------------------------------------------------------------------------

private fun startOfDayLocal(millis: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
}

private fun monthStart(millis: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    c.set(Calendar.DAY_OF_MONTH, 1)
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
}

private fun yearStart(millis: Long): Long {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    c.set(Calendar.MONTH, 0)
    c.set(Calendar.DAY_OF_MONTH, 1)
    c.set(Calendar.HOUR_OF_DAY, 0)
    c.set(Calendar.MINUTE, 0)
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    return c.timeInMillis
}

private fun addMonths(millis: Long, n: Int): Long {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    c.add(Calendar.MONTH, n)
    return c.timeInMillis
}

private fun addYears(millis: Long, n: Int): Long {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    c.add(Calendar.YEAR, n)
    return c.timeInMillis
}

private fun monthTitle(millis: Long): String {
    val c = Calendar.getInstance().apply { timeInMillis = millis }
    return "${MONTHS[c.get(Calendar.MONTH)]} ${c.get(Calendar.YEAR)}"
}

/** 42-or-fewer cells (null = padding) for the month grid, weeks starting Sunday. */
private fun monthCells(monthStart: Long): List<Long?> {
    val c = Calendar.getInstance().apply { timeInMillis = monthStart }
    val lead = c.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY
    val daysInMonth = c.getActualMaximum(Calendar.DAY_OF_MONTH)
    val cells = mutableListOf<Long?>()
    repeat(lead) { cells.add(null) }
    repeat(daysInMonth) { cells.add(monthStart + it * DAY_MILLIS) }
    while (cells.size % 7 != 0) cells.add(null)
    return cells
}
