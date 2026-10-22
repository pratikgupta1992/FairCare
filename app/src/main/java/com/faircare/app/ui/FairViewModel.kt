package com.faircare.app.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.faircare.app.data.Baby
import com.faircare.app.data.CareTask
import com.faircare.app.data.Caregiver
import com.faircare.app.data.CaregiverType
import com.faircare.app.data.Db
import com.faircare.app.data.Eligibility
import com.faircare.app.data.LogEntry
import com.faircare.app.logic.computeFairness
import com.faircare.app.logic.hourlyDominant
import com.faircare.app.logic.startOfDay
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Calendar

class FairViewModel(app: Application) : AndroidViewModel(app) {
    private val db = Db.get(app)

    private val _babies = MutableStateFlow<List<Baby>>(emptyList())
    val babies: StateFlow<List<Baby>> = _babies
    private val _caregivers = MutableStateFlow<List<Caregiver>>(emptyList())
    val caregivers: StateFlow<List<Caregiver>> = _caregivers
    private val _tasks = MutableStateFlow<List<CareTask>>(emptyList())
    val tasks: StateFlow<List<CareTask>> = _tasks

    /** bumped after every write so log queries refresh */
    private val refreshKey = MutableStateFlow(0)

    /** null = all babies */
    var selectedBabyId by mutableStateOf<Long?>(null)
    var selectedDayStart by mutableStateOf(startOfDay(System.currentTimeMillis()))
    /** analytics range in days */
    var analyticsDays by mutableStateOf(7)

    init {
        viewModelScope.launch(Dispatchers.IO) {
            db.ensureSeeded()
            refreshAll()
        }
    }

    private suspend fun refreshAll() = withContext(Dispatchers.IO) {
        _babies.value = db.getBabies()
        _caregivers.value = db.getCaregivers()
        _tasks.value = db.getTasks()
    }

    private fun bump() {
        viewModelScope.launch(Dispatchers.IO) {
            refreshAll()
            refreshKey.value += 1
        }
    }

    fun logsFlow(start: Long, end: Long, babyId: Long?): Flow<List<LogEntry>> =
        refreshKey.map { withContext(Dispatchers.IO) { db.getLogs(start, end, babyId) } }
            .flowOn(Dispatchers.IO)

    fun dayRange(): Pair<Long, Long> =
        selectedDayStart to selectedDayStart + 24 * 3_600_000L

    fun analyticsRange(): Pair<Long, Long> {
        val end = startOfDay(System.currentTimeMillis()) + 24 * 3_600_000L
        return (end - analyticsDays * 24 * 3_600_000L) to end
    }

    fun analyticsDaysList(): List<Long> {
        val (s, e) = analyticsRange()
        val days = mutableListOf<Long>()
        var d = s
        while (d < e) { days.add(d); d += 24 * 3_600_000L }
        return days
    }

    fun addLog(babyId: Long, caregiverId: Long, taskId: Long, start: Long, end: Long, note: String) {
        viewModelScope.launch(Dispatchers.IO) {
            db.insertLog(LogEntry(babyId = babyId, caregiverId = caregiverId, taskId = taskId, startMillis = start, endMillis = end, note = note))
            refreshKey.value += 1
        }
    }

    fun deleteLog(entry: LogEntry) {
        viewModelScope.launch(Dispatchers.IO) {
            db.deleteLog(entry.id)
            refreshKey.value += 1
        }
    }

    fun updateLog(entry: LogEntry) {
        viewModelScope.launch(Dispatchers.IO) {
            db.updateLog(entry)
            refreshKey.value += 1
        }
    }

    fun addBaby(name: String, color: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            db.insertBaby(Baby(name = name, color = color)); bump()
        }
    }

    fun deleteBaby(baby: Baby) {
        viewModelScope.launch(Dispatchers.IO) {
            db.deleteBaby(baby.id)
            if (selectedBabyId == baby.id) selectedBabyId = null
            bump()
        }
    }

    fun addCaregiver(name: String, type: CaregiverType, color: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            db.insertCaregiver(Caregiver(name = name, type = type, color = color)); bump()
        }
    }

    fun deleteCaregiver(c: Caregiver) {
        viewModelScope.launch(Dispatchers.IO) { db.deleteCaregiver(c.id); bump() }
    }

    fun addTask(name: String, emoji: String, weight: Float, eligibility: Eligibility, counts: Boolean) {
        viewModelScope.launch(Dispatchers.IO) {
            val sort = (_tasks.value.maxOfOrNull { it.sort } ?: 0) + 1
            db.insertTask(CareTask(name = name, emoji = emoji, weight = weight, eligibility = eligibility, countsTowardBalance = counts, isCustom = true, sort = sort))
            bump()
        }
    }

    fun updateTask(t: CareTask) {
        viewModelScope.launch(Dispatchers.IO) { db.updateTask(t); bump() }
    }

    fun deleteTask(t: CareTask) {
        viewModelScope.launch(Dispatchers.IO) { db.deleteTask(t.id); bump() }
    }

    fun shiftDay(delta: Int) {
        selectedDayStart += delta * 24 * 3_600_000L
    }

    fun jumpToDay(dayStart: Long) {
        selectedDayStart = dayStart
    }

    fun dayLabel(): String {
        val cal = Calendar.getInstance().apply { timeInMillis = selectedDayStart }
        val today = startOfDay(System.currentTimeMillis())
        return when (selectedDayStart) {
            today -> "Today"
            today - 24 * 3_600_000L -> "Yesterday"
            else -> "%1\$tb %1\$td".format(cal.time)
        }
    }
}

/** Convenience: fairness report as a Flow for a range. */
fun FairViewModel.reportFlow(start: Long, end: Long, babyId: Long?) =
    combine(
        logsFlow(start, end, babyId),
        tasks,
        caregivers
    ) { entries, ts, cs ->
        computeFairness(entries, ts.associateBy { it.id }, cs.associateBy { it.id })
    }

fun FairViewModel.heatmapFlow(days: List<Long>, babyId: Long?): Flow<Map<Pair<Int, Int>, Long>> {
    val start = days.firstOrNull() ?: return kotlinx.coroutines.flow.flowOf(emptyMap())
    val end = (days.lastOrNull() ?: start) + 24 * 3_600_000L
    return combine(logsFlow(start, end, babyId), tasks, caregivers) { entries, ts, cs ->
        hourlyDominant(entries, ts.associateBy { it.id }, cs.associateBy { it.id }, days)
    }
}
