package com.faircare.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitTouchSlopOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faircare.app.data.Caregiver
import com.faircare.app.data.CareTask
import com.faircare.app.data.CaregiverType
import com.faircare.app.data.Eligibility
import com.faircare.app.data.LogEntry
import com.faircare.app.logic.computeFairness
import com.faircare.app.logic.startOfDay
import com.faircare.app.ui.FairViewModel
import com.faircare.app.ui.components.BabyChips
import com.faircare.app.ui.components.ScoreRing
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

private data class SheetArgs(
    val startMillis: Long,
    val durationMin: Int = 60,
    val entryToEdit: LogEntry? = null
)

private val HOUR_HEIGHT = 64.dp
private const val SNAP_MIN = 15
private const val DAY_MILLIS = 24 * 3_600_000L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(vm: FairViewModel, autoOpenLog: Boolean = false) {
    val babies by vm.babies.collectAsState(initial = emptyList())
    val caregivers by vm.caregivers.collectAsState(initial = emptyList())
    val tasks by vm.tasks.collectAsState(initial = emptyList())
    val (dayStart, dayEnd) = vm.dayRange()
    val entries by vm.logsFlow(dayStart, dayEnd, vm.selectedBabyId)
        .collectAsState(initial = emptyList())

    var sheet by remember {
        mutableStateOf<SheetArgs?>(
            if (autoOpenLog) {
                val now = System.currentTimeMillis()
                SheetArgs(startMillis = now - now % 900_000L, durationMin = 30)
            } else null
        )
    }

    val report = remember(entries, tasks, caregivers) {
        computeFairness(entries, tasks.associateBy { it.id }, caregivers.associateBy { it.id })
    }
    val cgById = caregivers.associateBy { it.id }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = {
                val now = System.currentTimeMillis()
                sheet = SheetArgs(startMillis = now - now % 900_000L, durationMin = 30)
            }) { Icon(Icons.Default.Add, contentDescription = "Quick log") }
        }
    ) { pad ->
        Column(Modifier.fillMaxSize().padding(pad)) {
            BabyChips(
                babies = babies,
                selectedId = vm.selectedBabyId,
                onSelect = { vm.selectedBabyId = it },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )
            // date nav
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(onClick = { vm.shiftDay(-1) }) {
                    Icon(Icons.Default.ChevronLeft, contentDescription = "Previous day")
                }
                Text(vm.dayLabel(), fontWeight = FontWeight.Bold, fontSize = 18.sp)
                IconButton(onClick = { vm.shiftDay(1) }) {
                    Icon(Icons.Default.ChevronRight, contentDescription = "Next day")
                }
            }
            // fairness card
            Card(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    ScoreRing(report.score, size = 84.dp)
                    Spacer(Modifier.width(16.dp))
                    Column {
                        Text(report.verdict, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Spacer(Modifier.height(4.dp))
                        report.parentShare.forEach { (cgId, share) ->
                            val cg = cgById[cgId] ?: return@forEach
                            Text(
                                "${cg.name}: ${(share * 100).toInt()}%",
                                fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        }
                        if (report.score == null) {
                            Text(
                                "Log care for both parents to see the score.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
            // Outlook-style day timeline: drag blocks to move, drag the bottom edge to resize
            DayTimeline(
                dayStart = dayStart,
                entries = entries,
                caregivers = caregivers,
                tasks = tasks,
                vm = vm,
                onEditEntry = { e ->
                    sheet = SheetArgs(
                        startMillis = e.startMillis,
                        durationMin = e.durationMin.toInt(),
                        entryToEdit = e
                    )
                },
                onEmptyTap = { h ->
                    sheet = SheetArgs(
                        startMillis = dayStart + h * 3_600_000L,
                        durationMin = 60
                    )
                },
                modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp)
            )
        }
    }

    val args = sheet
    if (args != null) {
        ModalBottomSheet(
            onDismissRequest = { sheet = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ) {
            LogSheet(
                vm = vm,
                initialStart = args.startMillis,
                initialDuration = args.durationMin,
                entryToEdit = args.entryToEdit,
                onDone = { sheet = null }
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Outlook-style day timeline
// ---------------------------------------------------------------------------

/** entryId -> (lane, laneCount) for side-by-side overlapping blocks */
private fun assignLanes(entries: List<LogEntry>): Map<Long, Pair<Int, Int>> {
    val sorted = entries.sortedBy { it.startMillis }
    val laneEnds = mutableListOf<Long>()
    val laneOf = mutableMapOf<Long, Int>()
    for (e in sorted) {
        var lane = laneEnds.indexOfFirst { it <= e.startMillis }
        if (lane == -1) {
            laneEnds.add(e.endMillis)
            lane = laneEnds.size - 1
        } else {
            laneEnds[lane] = e.endMillis
        }
        laneOf[e.id] = lane
    }
    // transitive overlap clusters share a lane count
    val result = mutableMapOf<Long, Pair<Int, Int>>()
    val visited = mutableSetOf<Long>()
    for (e in sorted) {
        if (e.id in visited) continue
        val cluster = mutableListOf<LogEntry>()
        val queue = ArrayDeque<LogEntry>()
        queue.add(e)
        visited.add(e.id)
        while (queue.isNotEmpty()) {
            val cur = queue.removeFirst()
            cluster.add(cur)
            for (o in sorted) {
                if (o.id !in visited &&
                    o.startMillis < cur.endMillis && cur.startMillis < o.endMillis
                ) {
                    visited.add(o.id)
                    queue.add(o)
                }
            }
        }
        val maxLane = cluster.maxOf { laneOf[it.id] ?: 0 }
        cluster.forEach { result[it.id] = (laneOf[it.id] ?: 0) to (maxLane + 1) }
    }
    return result
}

private fun fmtTime(millis: Long): String =
    SimpleDateFormat("h:mm a", Locale.US).format(Date(millis))

/** compact range: "7:00–7:15 PM" (AM/PM once when both ends share it) */
private fun fmtRange(start: Long, end: Long): String {
    val s = Calendar.getInstance().apply { timeInMillis = start }
    val e = Calendar.getInstance().apply { timeInMillis = end }
    val sameMeridiem = s.get(Calendar.AM_PM) == e.get(Calendar.AM_PM) &&
        s.get(Calendar.DAY_OF_YEAR) == e.get(Calendar.DAY_OF_YEAR)
    val short = SimpleDateFormat("h:mm", Locale.US)
    val full = SimpleDateFormat("h:mm a", Locale.US)
    return if (sameMeridiem) "${short.format(Date(start))}–${full.format(Date(end))}"
    else "${full.format(Date(start))}–${full.format(Date(end))}"
}

private fun hourLabel(millis: Long): String =
    SimpleDateFormat("h a", Locale.US).format(Date(millis))

@Composable
private fun DayTimeline(
    dayStart: Long,
    entries: List<LogEntry>,
    caregivers: List<Caregiver>,
    tasks: List<CareTask>,
    vm: FairViewModel,
    onEditEntry: (LogEntry) -> Unit,
    onEmptyTap: (hour: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val cgById = caregivers.associateBy { it.id }
    val taskById = tasks.associateBy { it.id }
    val lanes = remember(entries) { assignLanes(entries) }
    val scroll = rememberScrollState()
    val density = LocalDensity.current
    val hourPx = with(density) { HOUR_HEIGHT.toPx() }
    val isToday = dayStart == startOfDay(System.currentTimeMillis())

    // start scrolled near "now" (today) or the first entry
    LaunchedEffect(dayStart) {
        val targetHour = when {
            isToday -> Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            else -> entries.minOfOrNull { ((it.startMillis - dayStart) / 3_600_000L).toInt() } ?: 6
        }.coerceIn(0, 20)
        scroll.scrollTo((targetHour * hourPx).toInt())
    }

    Row(modifier.verticalScroll(scroll)) {
        // hour gutter
        Column(Modifier.width(52.dp)) {
            repeat(24) { h ->
                Box(
                    Modifier.height(HOUR_HEIGHT),
                    contentAlignment = Alignment.TopCenter
                ) {
                    Text(
                        hourLabel(dayStart + h * 3_600_000L),
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 1.dp)
                    )
                }
            }
        }
        BoxWithConstraints(Modifier.weight(1f)) {
            val dayWidthPx = with(density) { maxWidth.toPx() }
            Box(
                Modifier
                    .height(HOUR_HEIGHT * 24)
                    .fillMaxWidth()
                    .clipToBounds()
            ) {
                // hour grid lines
                repeat(25) { h ->
                    Box(
                        Modifier
                            .offset(y = HOUR_HEIGHT * h)
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(
                                MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f)
                            )
                    )
                }
                // tap empty hour -> new log (behind the blocks)
                repeat(24) { h ->
                    Box(
                        Modifier
                            .offset(y = HOUR_HEIGHT * h)
                            .height(HOUR_HEIGHT)
                            .fillMaxWidth()
                            .clickable { onEmptyTap(h) }
                    )
                }
                // entry blocks
                entries.forEach { e ->
                    val (lane, laneCount) = lanes[e.id] ?: (0 to 1)
                    EntryBlock(
                        entry = e,
                        lane = lane,
                        laneCount = laneCount,
                        dayStart = dayStart,
                        dayWidthPx = dayWidthPx,
                        hourPx = hourPx,
                        caregiver = cgById[e.caregiverId],
                        task = taskById[e.taskId],
                        vm = vm,
                        onEdit = onEditEntry
                    )
                }
                // now-line
                if (isToday) {
                    val nowMin = (System.currentTimeMillis() - dayStart) / 60000.0
                    if (nowMin in 0.0..1440.0) {
                        val y = (nowMin / 60.0 * hourPx).toFloat()
                        Box(
                            Modifier
                                .offset { IntOffset(0, y.roundToInt()) }
                                .fillMaxWidth()
                                .height(2.dp)
                                .background(Color(0xFFE53935))
                        )
                        Box(
                            Modifier
                                .offset { IntOffset(2, (y - 5).roundToInt()) }
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFE53935))
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EntryBlock(
    entry: LogEntry,
    lane: Int,
    laneCount: Int,
    dayStart: Long,
    dayWidthPx: Float,
    hourPx: Float,
    caregiver: Caregiver?,
    task: CareTask?,
    vm: FairViewModel,
    onEdit: (LogEntry) -> Unit
) {
    val density = LocalDensity.current
    val startMin = (entry.startMillis - dayStart) / 60000.0
    val durMin = entry.durationMin.toDouble()
    val baseY = (startMin / 60.0 * hourPx).toFloat()
    val minHPx = with(density) { 30.dp.toPx() }
    val baseH = maxOf((durMin / 60.0 * hourPx).toFloat(), minHPx)

    // Reset via remember keys when the saved entry flows back in — avoids a
    // snap-back flicker between drop and the DB write landing.
    var dragDy by remember(entry.id, entry.startMillis) { mutableFloatStateOf(0f) }
    var resizeDh by remember(entry.id, entry.endMillis) { mutableFloatStateOf(0f) }

    val widthFrac = 1f / laneCount
    val xPx = lane * dayWidthPx * widthFrac
    val wDp = with(density) { (dayWidthPx * widthFrac - 3).toDp() }
    val hDp = with(density) { (baseH + resizeDh).toDp() }
    val bg = caregiver?.let { Color(it.color) } ?: Color.Gray
    // shared lanes get a compact treatment so text stays readable
    val compact = laneCount > 1
    val hPad = if (compact) 4.dp else 7.dp
    val textSize = if (compact) 11.sp else 12.sp

    // One gesture detector for the whole block. A touch starting in the bottom
    // edge zone resizes; anywhere else moves. Keyed on the whole entry so an
    // edit (e.g. Mom -> Dad) can't leave a stale copy in the gesture closure —
    // the old keys (id + start/end) meant a drag after an edit wrote the old
    // caregiver back to the database.
    // The resize zone is proportional so short blocks stay easy to grab & move.
    val handleZonePx = (baseH * 0.25f).coerceIn(
        with(density) { 10.dp.toPx() },
        with(density) { 18.dp.toPx() }
    )
    // live previews for the chips (composition-side only)
    val movePreviewMin = ((startMin + dragDy / hourPx * 60) / SNAP_MIN).roundToInt() * SNAP_MIN
    val resizePreviewMin = ((durMin + resizeDh / hourPx * 60) / SNAP_MIN).roundToInt() * SNAP_MIN

    Box(
        modifier = Modifier
            .offset { IntOffset(xPx.roundToInt(), (baseY + dragDy).roundToInt()) }
            .width(wDp)
            .height(hDp)
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .clickable { onEdit(entry) }
            .pointerInput(entry) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val resizing = down.position.y >= size.height - handleZonePx
                    var dy = 0f
                    val pastSlop = awaitTouchSlopOrCancellation(down.id) { change, overSlop ->
                        dy += overSlop.y
                        change.consume()
                    }
                    if (pastSlop != null) {
                        if (resizing) {
                            resizeDh = (resizeDh + dy).coerceAtLeast(minHPx - baseH)
                        } else {
                            dragDy += dy
                        }
                        var dragging = true
                        while (dragging) {
                            val event = awaitPointerEvent()
                            val change = event.changes.firstOrNull { it.id == down.id }
                            if (change == null || !change.pressed) {
                                dragging = false
                            } else {
                                val delta = change.position - change.previousPosition
                                if (delta != Offset.Zero) {
                                    if (resizing) {
                                        resizeDh = (resizeDh + delta.y)
                                            .coerceAtLeast(minHPx - baseH)
                                    } else {
                                        dragDy += delta.y
                                    }
                                    change.consume()
                                }
                            }
                            if (event.changes.all { !it.pressed }) dragging = false
                        }
                        // commit from live state — never from a stale closure
                        if (resizing) {
                            val rawDur = ((durMin + resizeDh / hourPx * 60) / SNAP_MIN).roundToInt() * SNAP_MIN
                            val snappedDur = rawDur.coerceAtLeast(SNAP_MIN)
                            val newEnd = entry.startMillis + snappedDur * 60000L
                            if (newEnd != entry.endMillis) {
                                vm.updateLog(entry.copy(endMillis = newEnd))
                            } else {
                                resizeDh = 0f
                            }
                        } else {
                            val rawStart = ((startMin + dragDy / hourPx * 60) / SNAP_MIN).roundToInt() * SNAP_MIN
                            val snapped = rawStart.coerceIn(0, (24 * 60 - durMin).toInt())
                            val newStart = dayStart + snapped * 60000L
                            if (newStart != entry.startMillis) {
                                val dur = entry.endMillis - entry.startMillis
                                vm.updateLog(
                                    entry.copy(startMillis = newStart, endMillis = newStart + dur)
                                )
                            } else {
                                dragDy = 0f
                            }
                        }
                    }
                }
            }
            .padding(start = hPad, end = hPad, top = 3.dp, bottom = 2.dp)
    ) {
        // single info line: "Dad • ⭐ General Care • 7:00–7:15 PM"
        val line = remember(entry.id, entry.startMillis, entry.endMillis, caregiver?.name, task?.name) {
            buildAnnotatedString {
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                    append(caregiver?.name ?: "?")
                }
                if (task != null) append(" • ${task.emoji} ${task.name}")
                append(" • ${fmtRange(entry.startMillis, entry.endMillis)}")
            }
        }
        Text(
            text = line,
            fontSize = textSize,
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        // live chip while dragging: time for moves, duration for resizes
        if (dragDy != 0f || resizeDh != 0f) {
            val label = if (resizeDh != 0f) {
                formatDuration(resizePreviewMin.coerceAtLeast(SNAP_MIN))
            } else {
                fmtTime(dayStart + movePreviewMin.coerceIn(0, 1439) * 60000L)
            }
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.Black.copy(alpha = 0.72f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(label, fontSize = 10.sp, color = Color.White)
            }
        }
        // bottom-edge resize grip (visual cue; the gesture above handles it)
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(14.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                Modifier
                    .width(30.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.85f))
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Log sheet (create + edit)
// ---------------------------------------------------------------------------

/** 90 -> "1h 30m" (the old "${d/60}h" label showed "1h" for both 60 and 90). */
private fun formatDuration(d: Int): String = when {
    d < 60 -> "${d}m"
    d % 60 == 0 -> "${d / 60}h"
    else -> "${d / 60}h ${d % 60}m"
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun LogSheet(
    vm: FairViewModel,
    initialStart: Long,
    initialDuration: Int,
    entryToEdit: LogEntry? = null,
    onDone: () -> Unit
) {
    val babies by vm.babies.collectAsState(initial = emptyList())
    val caregivers by vm.caregivers.collectAsState(initial = emptyList())
    val tasks by vm.tasks.collectAsState(initial = emptyList())
    val (dayStart, dayEnd) = vm.dayRange()
    val entries by vm.logsFlow(dayStart, dayEnd, vm.selectedBabyId)
        .collectAsState(initial = emptyList())

    val edit = entryToEdit
    // NOTE: never snapshot the async lists in remember — collectAsState's first
    // composition sees the initial emptyList(), so a remember{} here would freeze
    // the ids at 0L (this once left Save permanently disabled). Resolve live,
    // with the user's explicit picks taking precedence. Keyed by the edited
    // entry so opening the sheet for another entry re-prefills.
    var babyId by remember(edit?.id) { mutableStateOf(edit?.babyId ?: vm.selectedBabyId) }
    var caregiverId by remember(edit?.id) { mutableStateOf<Long?>(edit?.caregiverId) }
    var taskId by remember(edit?.id) { mutableStateOf<Long?>(edit?.taskId) }
    val resolvedBabyId = babyId ?: babies.firstOrNull()?.id ?: 0L
    val resolvedCaregiverId = caregiverId
        ?: caregivers.firstOrNull { it.type.isParent }?.id
        ?: caregivers.firstOrNull()?.id ?: 0L
    val resolvedTaskId = taskId ?: tasks.firstOrNull()?.id ?: 0L
    var duration by remember(edit?.id) { mutableStateOf(edit?.durationMin?.toInt() ?: initialDuration) }
    var startMillis by remember(edit?.id) { mutableStateOf(edit?.startMillis ?: initialStart) }
    var note by remember(edit?.id) { mutableStateOf(edit?.note ?: "") }

    val task = tasks.firstOrNull { it.id == resolvedTaskId }
    val caregiver = caregivers.firstOrNull { it.id == resolvedCaregiverId }
    val eligibilityError = task != null && task.eligibility == Eligibility.MOTHER_ONLY &&
        caregiver?.type != CaregiverType.MOTHER

    val hStart = startOfHour(startMillis)
    val hourEntries = entries.filter { it.startMillis < hStart + 3_600_000L && it.endMillis > hStart }

    Column(Modifier.fillMaxWidth().padding(16.dp)) {
        Text(
            if (edit != null) "Edit log" else "Log care",
            fontWeight = FontWeight.Bold,
            fontSize = 18.sp
        )
        Spacer(Modifier.height(8.dp))

        if (vm.selectedBabyId == null && babies.size > 1) {
            Text("Baby", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                babies.forEach { b ->
                    FilterChip(
                        selected = resolvedBabyId == b.id,
                        onClick = { babyId = b.id },
                        label = { Text(b.name) }
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        Text("Who", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            caregivers.forEach { c ->
                FilterChip(
                    selected = resolvedCaregiverId == c.id,
                    onClick = { caregiverId = c.id },
                    label = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(Color(c.color)))
                            Spacer(Modifier.width(4.dp))
                            Text(c.name)
                        }
                    }
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        Text("What", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            tasks.forEach { t ->
                FilterChip(
                    selected = resolvedTaskId == t.id,
                    onClick = { taskId = t.id },
                    label = { Text("${t.emoji} ${t.name}") }
                )
            }
        }
        if (task != null) {
            Text(
                "Rule: ${task.eligibility.label} · weight ${task.weight}×" +
                    (if (task.eligibility == Eligibility.MOTHER_ONLY) " · counts for Mom" else ""),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
        if (eligibilityError) {
            Text(
                "⚠️ ${task?.name} can only be logged for Mom.",
                color = MaterialTheme.colorScheme.error,
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 4.dp)
            )
        }
        Spacer(Modifier.height(8.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Start", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.width(8.dp))
            TextButton(onClick = { startMillis -= 900_000L }) { Text("−15m") }
            Text(
                SimpleDateFormat("h:mm a", Locale.US).format(Date(startMillis)),
                fontWeight = FontWeight.Medium
            )
            TextButton(onClick = { startMillis += 900_000L }) { Text("+15m") }
            Spacer(Modifier.width(8.dp))
            Text("Length", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(15, 30, 45, 60, 90, 120).forEach { d ->
                FilterChip(
                    selected = duration == d,
                    onClick = { duration = d },
                    label = { Text(formatDuration(d)) }
                )
            }
        }
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = note,
            onValueChange = { note = it },
            label = { Text("Note (optional)") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = {
                if (edit != null) {
                    vm.updateLog(
                        edit.copy(
                            babyId = resolvedBabyId,
                            caregiverId = resolvedCaregiverId,
                            taskId = resolvedTaskId,
                            startMillis = startMillis,
                            endMillis = startMillis + duration * 60_000L,
                            note = note.trim()
                        )
                    )
                } else {
                    vm.addLog(
                        resolvedBabyId,
                        resolvedCaregiverId,
                        resolvedTaskId,
                        startMillis,
                        startMillis + duration * 60_000L,
                        note.trim()
                    )
                }
                onDone()
            },
            enabled = !eligibilityError && resolvedBabyId != 0L && resolvedCaregiverId != 0L && resolvedTaskId != 0L,
            modifier = Modifier.fillMaxWidth()
        ) { Text(if (edit != null) "Save changes" else "Save") }

        if (edit != null) {
            Spacer(Modifier.height(4.dp))
            TextButton(
                onClick = { vm.deleteLog(edit); onDone() },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Delete entry", color = MaterialTheme.colorScheme.error)
            }
        }

        if (edit == null && hourEntries.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text("Already logged this hour", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            hourEntries.forEach { e ->
                val cg = caregivers.firstOrNull { it.id == e.caregiverId }
                val t = tasks.firstOrNull { it.id == e.taskId }
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "${t?.emoji ?: ""} ${cg?.name ?: "?"} · ${formatDuration(e.durationMin.toInt())}",
                        Modifier.weight(1f),
                        fontSize = 13.sp,
                        textAlign = TextAlign.Start
                    )
                    IconButton(onClick = { vm.deleteLog(e) }) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

private fun startOfHour(millis: Long): Long = millis - millis % 3_600_000L
