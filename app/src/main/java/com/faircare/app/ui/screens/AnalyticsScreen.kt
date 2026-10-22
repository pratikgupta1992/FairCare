package com.faircare.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.faircare.app.logic.computeFairness
import com.faircare.app.ui.FairViewModel
import com.faircare.app.ui.components.BabyChips
import com.faircare.app.ui.components.Heatmap
import com.faircare.app.ui.components.ScoreRing
import com.faircare.app.ui.components.SplitBar
import com.faircare.app.ui.components.TaskSplitRow
import com.faircare.app.ui.heatmapFlow
import com.faircare.app.ui.reportFlow
import com.faircare.app.util.buildCsv
import com.faircare.app.util.shareCsv
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AnalyticsScreen(vm: FairViewModel) {
    val context = LocalContext.current
    val babies by vm.babies.collectAsState(initial = emptyList())
    val caregivers by vm.caregivers.collectAsState(initial = emptyList())
    val tasks by vm.tasks.collectAsState(initial = emptyList())

    val (rStart, rEnd) = vm.analyticsRange()
    val report by vm.reportFlow(rStart, rEnd, vm.selectedBabyId)
        .collectAsState(
            initial = computeFairness(
                emptyList(), tasks.associateBy { it.id }, caregivers.associateBy { it.id }
            )
        )
    val days = remember(vm.analyticsDays, rStart) { vm.analyticsDaysList().take(14) }
    val heat by vm.heatmapFlow(days, vm.selectedBabyId)
        .collectAsState(initial = emptyMap())
    val entries by vm.logsFlow(rStart, rEnd, vm.selectedBabyId)
        .collectAsState(initial = emptyList())

    val cgById = caregivers.associateBy { it.id }
    val taskById = tasks.associateBy { it.id }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
    ) {
        Spacer(Modifier.height(8.dp))
        BabyChips(babies, vm.selectedBabyId, { vm.selectedBabyId = it })
        Spacer(Modifier.height(8.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(1 to "Today", 7 to "7 days", 30 to "30 days").forEach { (d, label) ->
                FilterChip(
                    selected = vm.analyticsDays == d,
                    onClick = { vm.analyticsDays = d },
                    label = { Text(label) }
                )
            }
        }
        Spacer(Modifier.height(8.dp))

        // score card
        Card(
            Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
        ) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                ScoreRing(report.score, size = 100.dp)
                Spacer(Modifier.padding(8.dp))
                Column {
                    Text(report.verdict, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${report.totalMinutes / 60}h ${report.totalMinutes % 60}m of parental care logged",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    if (report.outsourcedShare > 0.01) {
                        Text(
                            "Nanny/daycare covered ${(report.outsourcedShare * 100).roundToInt()}% of all care",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))

        // parent split
        if (report.parentShare.isNotEmpty()) {
            Text("Parental share", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Spacer(Modifier.height(6.dp))
            SplitBar(
                report.parentShare.map { (cgId, share) ->
                    val cg = cgById[cgId]
                    Triple(
                        cg?.name ?: "?",
                        cg?.let { Color(it.color) } ?: Color.Gray,
                        share
                    )
                }
            )
            Spacer(Modifier.height(12.dp))
        }

        // who does what
        if (report.perTask.isNotEmpty()) {
            Text("Who does what", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            report.perTask.take(12).forEach { split ->
                val t = taskById[split.taskId] ?: return@forEach
                TaskSplitRow(
                    emoji = t.emoji,
                    name = t.name,
                    shares = split.byCaregiver.map { (cgId, pts) ->
                        val cg = cgById[cgId]
                        Triple(
                            cg?.name ?: "?",
                            cg?.let { Color(it.color) } ?: Color.Gray,
                            if (split.total > 0) pts / split.total else 0.0
                        )
                    }
                )
            }
            Spacer(Modifier.height(12.dp))
        }

        // heatmap
        if (days.isNotEmpty()) {
            Text("When care happens", fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Spacer(Modifier.height(6.dp))
            Heatmap(
                days = days,
                cells = heat,
                caregiverColor = { id -> cgById[id]?.let { Color(it.color) } ?: Color.Gray },
                dayLabel = { SimpleDateFormat("EE", Locale.US).format(Date(it)) }
            )
            Spacer(Modifier.height(12.dp))
        }

        // how it works
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text("How the fairness score works", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.height(6.dp))
                Text(
                    "Every log becomes effort points: minutes × task weight × night bonus (1.5× for 10pm–6am). " +
                        "Breastfeeding and pumping (1.5×, mom-only) count fully for Mom — " +
                        "Dad supervising at the same time (0.7×) doesn't cancel it out. " +
                        "The score is 100 when parents split points evenly, 0 when one parent does it all. " +
                        "Nanny/daycare time is tracked separately so paid help never masks the parental split.",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        Button(
            onClick = {
                val csv = buildCsv(
                    entries,
                    babies.associateBy { it.id },
                    caregivers.associateBy { it.id },
                    tasks.associateBy { it.id }
                )
                shareCsv(context, csv)
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("Export log as CSV (settle it with data 📊)") }
        Spacer(Modifier.height(80.dp))
    }
}
