package com.faircare.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

/** Circular fairness score gauge, 0..100. */
@Composable
fun ScoreRing(score: Double?, modifier: Modifier = Modifier, size: Dp = 120.dp) {
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.size(size)) {
            val stroke = 14.dp.toPx()
            drawArc(
                color = Color.LightGray.copy(alpha = 0.35f),
                startAngle = 135f, sweepAngle = 270f, useCenter = false,
                style = Stroke(stroke, cap = StrokeCap.Round),
                size = Size(size.toPx() - stroke, size.toPx() - stroke),
                topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2)
            )
            if (score != null) {
                val c = when {
                    score >= 90 -> Color(0xFF2E9E5B)
                    score >= 75 -> Color(0xFF7CB342)
                    score >= 60 -> Color(0xFFE8A13D)
                    else -> Color(0xFFE05252)
                }
                drawArc(
                    color = c,
                    startAngle = 135f, sweepAngle = (270f * score / 100).toFloat(),
                    useCenter = false,
                    style = Stroke(stroke, cap = StrokeCap.Round),
                    size = Size(size.toPx() - stroke, size.toPx() - stroke),
                    topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2)
                )
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = score?.roundToInt()?.toString() ?: "–",
                fontSize = 30.sp, fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text("fairness", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Stacked horizontal share bar with legend. */
@Composable
fun SplitBar(
    segments: List<Triple<String, Color, Double>>, // label, color, fraction 0..1
    modifier: Modifier = Modifier
) {
    Column(modifier) {
        Row(
            Modifier.fillMaxWidth().height(22.dp)
                .clip(RoundedCornerShape(11.dp))
                .background(Color.LightGray.copy(alpha = 0.25f))
        ) {
            segments.forEach { (_, color, frac) ->
                if (frac > 0.005) {
                    Box(
                        Modifier
                            .weight(frac.toFloat())
                            .height(22.dp)
                            .background(color)
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            segments.forEach { (label, color, frac) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(10.dp).clip(CircleShape).background(color))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "$label ${(frac * 100).roundToInt()}%",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

/** One task's split between caregivers: dual bars. */
@Composable
fun TaskSplitRow(
    emoji: String,
    name: String,
    shares: List<Triple<String, Color, Double>>,
    modifier: Modifier = Modifier
) {
    Column(modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(emoji, fontSize = 18.sp)
            Spacer(Modifier.width(8.dp))
            Text(name, fontWeight = FontWeight.Medium, fontSize = 14.sp)
        }
        Spacer(Modifier.height(4.dp))
        SplitBar(shares)
    }
}

/** 7 x 24 (or N x 24) heatmap: dominant caregiver per hour cell. */
@Composable
fun Heatmap(
    days: List<Long>,
    cells: Map<Pair<Int, Int>, Long>, // (dayIdx, hour) -> caregiverId
    caregiverColor: (Long) -> Color,
    dayLabel: (Long) -> String,
    modifier: Modifier = Modifier
) {
    Column(modifier) {
        // hour header
        Row {
            Spacer(Modifier.width(34.dp))
            for (h in listOf(0, 6, 12, 18)) {
                Text(
                    "%02d".format(h), fontSize = 9.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(48.dp)
                )
            }
        }
        days.forEachIndexed { di, dayStart ->
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 1.dp)) {
                Text(
                    dayLabel(dayStart), fontSize = 9.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.width(34.dp)
                )
                for (h in 0 until 24) {
                    val cgId = cells[di to h]
                    Box(
                        Modifier
                            .size(13.dp)
                            .padding(1.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(
                                if (cgId != null) caregiverColor(cgId)
                                else Color.LightGray.copy(alpha = 0.18f)
                            )
                    )
                }
            }
        }
    }
}
