package com.faircare.app.logic

import com.faircare.app.data.CareTask
import com.faircare.app.data.Caregiver
import com.faircare.app.data.CaregiverType
import com.faircare.app.data.LogEntry
import java.util.Calendar

/** Night hours get this multiplier — night duty is harder. */
const val NIGHT_MULTIPLIER = 1.5

fun isNightHour(hourOfDay: Int): Boolean = hourOfDay >= 22 || hourOfDay < 6

/** Split an entry's minutes into (dayMinutes, nightMinutes) by walking hour boundaries. */
fun splitDayNight(start: Long, end: Long): Pair<Long, Long> {
    var day = 0L
    var night = 0L
    var t = start
    val cal = Calendar.getInstance()
    var guard = 0
    while (t < end && guard++ < 100) {
        cal.timeInMillis = t
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val nextBoundary = (t / 3_600_000L + 1) * 3_600_000L
        val chunkEnd = minOf(nextBoundary, end)
        val mins = ((chunkEnd - t) / 60_000L).coerceAtLeast(0)
        if (isNightHour(hour)) night += mins else day += mins
        t = chunkEnd
    }
    return day to night
}

/**
 * Weighted effort points for one log entry.
 * points = (dayMin + nightMin * 1.5) * task.weight
 *
 * This is what makes the fairness score "judge" tasks differently:
 * pumping (1.5x, mom-only) vs. supervising (0.7x) during the same half hour
 * is NOT scored as balanced — the points say otherwise.
 */
fun weightedPoints(entry: LogEntry, task: CareTask): Double {
    if (!task.countsTowardBalance) return 0.0
    val (day, night) = splitDayNight(entry.startMillis, entry.endMillis)
    return (day + night * NIGHT_MULTIPLIER) * task.weight
}

data class TaskSplit(
    val taskId: Long,
    val byCaregiver: Map<Long, Double>,
    val total: Double
)

data class FairnessReport(
    /** 0..100. Null when fewer than two parents have logged points. */
    val score: Double?,
    val verdict: String,
    /** caregiverId -> share of parental points (0..1), parents only */
    val parentShare: Map<Long, Double>,
    val parentPoints: Map<Long, Double>,
    /** share of ALL points done by nanny/daycare (0..1) */
    val outsourcedShare: Double,
    val perTask: List<TaskSplit>,
    val totalParentalPoints: Double,
    val totalMinutes: Long
)

fun verdictFor(score: Double): String = when {
    score >= 90 -> "Beautifully balanced ⚖️"
    score >= 75 -> "Mostly fair \uD83D\uDC4C"
    score >= 60 -> "Leaning on one parent"
    else -> "Time to rebalance \uD83D\uDE05"
}

fun computeFairness(
    entries: List<LogEntry>,
    tasks: Map<Long, CareTask>,
    caregivers: Map<Long, Caregiver>
): FairnessReport {
    val parentPts = mutableMapOf<Long, Double>()
    val byTask = mutableMapOf<Long, MutableMap<Long, Double>>()
    var external = 0.0
    var total = 0.0
    var mins = 0L

    for (e in entries) {
        val task = tasks[e.taskId] ?: continue
        val cg = caregivers[e.caregiverId] ?: continue
        val pts = weightedPoints(e, task)
        total += pts
        mins += e.durationMin
        byTask.getOrPut(e.taskId) { mutableMapOf() }
            .merge(e.caregiverId, pts, Double::plus)
        if (cg.type.isParent) {
            parentPts.merge(e.caregiverId, pts, Double::plus)
        } else if (cg.type.isPaidExternal) {
            external += pts
        }
    }

    val parentTotal = parentPts.values.sum()
    val activeParents = parentPts.count { it.value > 0 }
    val score = if (activeParents >= 2 && parentTotal > 0) {
        val max = parentPts.values.max()
        val min = parentPts.values.min()
        (100.0 * (1.0 - (max - min) / parentTotal)).coerceIn(0.0, 100.0)
    } else null

    return FairnessReport(
        score = score,
        verdict = score?.let { verdictFor(it) } ?: "Log both parents to see the score",
        parentShare = parentPts.mapValues { (_, v) -> if (parentTotal > 0) v / parentTotal else 0.0 },
        parentPoints = parentPts.toMap(),
        outsourcedShare = if (total > 0) external / total else 0.0,
        perTask = byTask.map { (taskId, m) -> TaskSplit(taskId, m.toMap(), m.values.sum()) }
            .sortedByDescending { it.total },
        totalParentalPoints = parentTotal,
        totalMinutes = mins
    )
}

/**
 * For each (dayIndex, hour) cell, the caregiverId with the most weighted points,
 * or null when empty. Used by the hourly heatmap.
 */
fun hourlyDominant(
    entries: List<LogEntry>,
    tasks: Map<Long, CareTask>,
    caregivers: Map<Long, Caregiver>,
    dayStarts: List<Long> // epoch millis of each day's 00:00, ascending
): Map<Pair<Int, Int>, Long> {
    val cellPts = mutableMapOf<Pair<Int, Int>, MutableMap<Long, Double>>()
    val cal = Calendar.getInstance()
    for (e in entries) {
        val task = tasks[e.taskId] ?: continue
        if (caregivers[e.caregiverId] == null) continue
        var t = e.startMillis
        var guard = 0
        while (t < e.endMillis && guard++ < 200) {
            cal.timeInMillis = t
            val dayStart = dayStarts.lastOrNull { it <= t } ?: continue
            val dayIdx = dayStarts.indexOf(dayStart)
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val nextBoundary = (t / 3_600_000L + 1) * 3_600_000L
            val chunkEnd = minOf(nextBoundary, e.endMillis)
            val mins = ((chunkEnd - t) / 60_000L).coerceAtLeast(0)
            if (mins > 0) {
                val pts = mins * task.weight *
                    (if (isNightHour(hour)) NIGHT_MULTIPLIER else 1.0)
                cellPts.getOrPut(dayIdx to hour) { mutableMapOf() }
                    .merge(e.caregiverId, pts, Double::plus)
            }
            t = chunkEnd
        }
    }
    return cellPts.mapValues { (_, m) -> m.maxBy { it.value }.key }
}

fun startOfDay(millis: Long): Long {
    val cal = Calendar.getInstance().apply { timeInMillis = millis }
    cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}

fun caregiverColorHex(color: Int): String = String.format("#%06X", 0xFFFFFF and color)
