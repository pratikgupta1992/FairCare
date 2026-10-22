package com.faircare.app.data

enum class CaregiverType {
    MOTHER, FATHER, OTHER_PARENT, NANNY, DAYCARE, FAMILY;

    val isParent: Boolean
        get() = this == MOTHER || this == FATHER || this == OTHER_PARENT

    val isPaidExternal: Boolean
        get() = this == NANNY || this == DAYCARE

    val label: String
        get() = when (this) {
            MOTHER -> "Mom"
            FATHER -> "Dad"
            OTHER_PARENT -> "Parent"
            NANNY -> "Nanny"
            DAYCARE -> "Daycare"
            FAMILY -> "Family"
        }
}

enum class Eligibility {
    ANYONE, MOTHER_ONLY;

    val label: String
        get() = when (this) {
            ANYONE -> "Anyone"
            MOTHER_ONLY -> "Mom only"
        }
}

data class Baby(
    val id: Long = 0,
    val name: String,
    val color: Int
)

data class Caregiver(
    val id: Long = 0,
    val name: String,
    val type: CaregiverType,
    val color: Int
)

data class CareTask(
    val id: Long = 0,
    val name: String,
    val emoji: String,
    /** Effort weight: 1.0 = standard. Higher = harder / more draining. */
    val weight: Float = 1f,
    val eligibility: Eligibility = Eligibility.ANYONE,
    val countsTowardBalance: Boolean = true,
    val isCustom: Boolean = false,
    val sort: Int = 0
)

data class LogEntry(
    val id: Long = 0,
    val babyId: Long,
    val caregiverId: Long,
    val taskId: Long,
    val startMillis: Long,
    val endMillis: Long,
    val note: String = ""
) {
    val durationMin: Long get() = ((endMillis - startMillis) / 60000L).coerceAtLeast(0)
}
