package com.faircare.app.util

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.faircare.app.data.Baby
import com.faircare.app.data.CareTask
import com.faircare.app.data.Caregiver
import com.faircare.app.data.LogEntry
import com.faircare.app.logic.splitDayNight
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun buildCsv(
    entries: List<LogEntry>,
    babies: Map<Long, Baby>,
    caregivers: Map<Long, Caregiver>,
    tasks: Map<Long, CareTask>
): String {
    val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
    val sb = StringBuilder()
    sb.appendLine("start,end,date,duration_min,day_min,night_min,baby,caregiver,caregiver_type,task,task_weight,note")
    for (e in entries.sortedBy { it.startMillis }) {
        val (day, night) = splitDayNight(e.startMillis, e.endMillis)
        fun esc(s: String) = "\"" + s.replace("\"", "\"\"") + "\""
        sb.appendLine(
            listOf(
                fmt.format(Date(e.startMillis)),
                fmt.format(Date(e.endMillis)),
                SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(e.startMillis)),
                e.durationMin.toString(),
                day.toString(),
                night.toString(),
                esc(babies[e.babyId]?.name ?: "?"),
                esc(caregivers[e.caregiverId]?.name ?: "?"),
                caregivers[e.caregiverId]?.type?.name ?: "?",
                esc(tasks[e.taskId]?.name ?: "?"),
                (tasks[e.taskId]?.weight ?: 1f).toString(),
                esc(e.note)
            ).joinToString(",")
        )
    }
    return sb.toString()
}

fun shareCsv(context: Context, csv: String) {
    val dir = File(context.cacheDir, "exports").apply { mkdirs() }
    val file = File(dir, "faircare-log.csv").apply { writeText(csv) }
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/csv"
        putExtra(Intent.EXTRA_STREAM, uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "Share FairCare log"))
}
