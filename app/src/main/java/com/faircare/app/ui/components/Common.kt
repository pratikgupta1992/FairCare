package com.faircare.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.faircare.app.data.Baby

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BabyChips(
    babies: List<Baby>,
    selectedId: Long?,
    onSelect: (Long?) -> Unit,
    modifier: Modifier = Modifier
) {
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(
            selected = selectedId == null,
            onClick = { onSelect(null) },
            label = { Text("All babies") }
        )
        babies.forEach { b ->
            FilterChip(
                selected = selectedId == b.id,
                onClick = { onSelect(b.id) },
                label = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(10.dp).clip(CircleShape).background(Color(b.color)))
                        Spacer(Modifier.width(4.dp))
                        Text(b.name)
                    }
                }
            )
        }
    }
}

val PALETTE = listOf(
    0xFFE57373, 0xFF64B5F6, 0xFFFFD54F, 0xFF81C784, 0xFFBA68C8,
    0xFFFF8A65, 0xFF4DB6AC, 0xFF90A4AE
).map { it.toInt() }
